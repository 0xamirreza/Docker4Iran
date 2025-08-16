#!/usr/bin/env python3
"""
Interactive Docker Registry Mirror Selector
Tests Docker registry mirrors and allows user to choose from ranked results
"""

import json
import time
import subprocess
import sys
import os
import requests
import urllib3
from typing import Dict, List, Tuple, Optional

# Disable SSL warnings
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class InteractiveRegistrySelector:
    def __init__(self, registry_config_path: str = "conf/docker.json"):
        self.registry_config_path = registry_config_path
        self.registry_mirrors = self._load_registry_config()
        self.daemon_json_path = "/etc/docker/daemon.json"
        
    def _load_registry_config(self) -> List[Dict]:
        """Load registry mirror configuration from docker.json file"""
        try:
            registries = []
            with open(self.registry_config_path, 'r') as f:
                content = f.read()
                
            # Parse multiple JSON objects separated by comments
            json_blocks = []
            current_block = ""
            
            for line in content.split('\n'):
                line = line.strip()
                if line.startswith('#') or not line:
                    if current_block.strip():
                        json_blocks.append(current_block)
                        current_block = ""
                else:
                    current_block += line + '\n'
            
            if current_block.strip():
                json_blocks.append(current_block)
            
            for i, block in enumerate(json_blocks):
                try:
                    registry_config = json.loads(block)
                    if 'registry-mirrors' in registry_config:
                        for mirror in registry_config['registry-mirrors']:
                            registries.append({
                                'name': f'Registry_{i+1}',
                                'mirror': mirror,
                                'insecure': mirror in registry_config.get('insecure-registries', [])
                            })
                except json.JSONDecodeError:
                    continue
                    
            return registries
            
        except FileNotFoundError:
            print(f"❌ Registry config file not found: {self.registry_config_path}")
            sys.exit(1)
        except Exception as e:
            print(f"❌ Error loading registry config: {e}")
            sys.exit(1)
    
    def _test_registry_connectivity(self, mirror: str, timeout: int = 10) -> Tuple[bool, float]:
        """Test registry mirror connectivity and response time"""
        try:
            # Clean mirror URL for testing
            test_url = mirror.rstrip('/')
            if not test_url.startswith('http'):
                test_url = f"https://{test_url}"
            
            # Test basic connectivity
            start_time = time.time()
            response = requests.get(f"{test_url}/v2/", timeout=timeout, verify=False)
            end_time = time.time()
            
            response_time = end_time - start_time
            
            # Check if we get a valid Docker registry response
            if response.status_code in [200, 401, 404]:  # 401 is normal for registry auth
                return True, response_time
            else:
                return False, float('inf')
                
        except Exception:
            return False, float('inf')
    
    def _test_docker_hub_connectivity(self, mirror: str, timeout: int = 15) -> Tuple[bool, float]:
        """Test Docker Hub connectivity through the mirror"""
        try:
            # Test if we can reach Docker Hub through this mirror
            test_url = mirror.rstrip('/')
            if not test_url.startswith('http'):
                test_url = f"https://{test_url}"
            
            start_time = time.time()
            # Try to get manifest for hello-world image
            response = requests.get(
                f"{test_url}/v2/library/hello-world/manifests/latest",
                headers={'Accept': 'application/vnd.docker.distribution.manifest.v2+json'},
                timeout=timeout,
                verify=False
            )
            end_time = time.time()
            
            response_time = end_time - start_time
            
            if response.status_code in [200, 401, 404]:
                return True, response_time
            else:
                return False, float('inf')
                
        except Exception:
            return False, float('inf')
    
    def _test_single_registry(self, registry: Dict) -> Dict:
        """Test a single registry mirror"""
        mirror = registry['mirror']
        name = registry['name']
        
        print(f"🔍 Testing {name}: {mirror}")
        
        results = {
            'name': name,
            'mirror': mirror,
            'insecure': registry['insecure'],
            'connectivity_success': False,
            'connectivity_time': float('inf'),
            'hub_success': False,
            'hub_time': float('inf'),
            'total_score': float('inf'),
            'status': 'Failed'
        }
        
        # Test basic connectivity
        conn_success, conn_time = self._test_registry_connectivity(mirror)
        results['connectivity_success'] = conn_success
        results['connectivity_time'] = conn_time
        
        if conn_success:
            print(f"  ✅ Connectivity: {conn_time:.2f}s")
            
            # Test Docker Hub connectivity
            hub_success, hub_time = self._test_docker_hub_connectivity(mirror)
            results['hub_success'] = hub_success
            results['hub_time'] = hub_time
            
            if hub_success:
                print(f"  ✅ Docker Hub access: {hub_time:.2f}s")
                # Calculate score (lower is better)
                results['total_score'] = conn_time + (hub_time * 1.5)  # Weight hub access more
                results['status'] = 'Working'
            else:
                print(f"  ⚠️  Docker Hub access failed")
                results['status'] = 'Hub Access Failed'
        else:
            print(f"  ❌ Connectivity failed")
            results['status'] = 'Connection Failed'
        
        return results
    
    def test_all_registries(self) -> List[Dict]:
        """Test all registry mirrors and return results"""
        print("🚀 Starting Docker Registry Mirror Connectivity Test")
        print(f"📋 Found {len(self.registry_mirrors)} registry mirrors to test")
        print("=" * 60)
        
        results = []
        
        for registry in self.registry_mirrors:
            result = self._test_single_registry(registry)
            results.append(result)
            print()
        
        return results
    
    def _configure_docker_daemon(self, selected_mirror: Dict) -> bool:
        """Configure Docker daemon with the selected mirror"""
        try:
            daemon_config = {}
            
            # Load existing daemon.json if it exists
            if os.path.exists(self.daemon_json_path):
                try:
                    with open(self.daemon_json_path, 'r') as f:
                        daemon_config = json.load(f)
                except json.JSONDecodeError:
                    daemon_config = {}
            
            # Set registry mirrors
            daemon_config['registry-mirrors'] = [selected_mirror['mirror']]
            
            # Add insecure registry if needed
            if selected_mirror['insecure']:
                if 'insecure-registries' not in daemon_config:
                    daemon_config['insecure-registries'] = []
                if selected_mirror['mirror'] not in daemon_config['insecure-registries']:
                    daemon_config['insecure-registries'].append(selected_mirror['mirror'])
            
            # Write daemon.json
            with open(self.daemon_json_path, 'w') as f:
                json.dump(daemon_config, f, indent=2)
            
            # Restart Docker daemon
            result = subprocess.run(['systemctl', 'restart', 'docker'], 
                                  capture_output=True, text=True)
            
            if result.returncode != 0:
                print(f"❌ Failed to restart Docker: {result.stderr}")
                return False
            
            # Wait for Docker to be ready
            time.sleep(5)
            
            # Verify Docker is running
            verify_result = subprocess.run(['docker', 'info'], 
                                         capture_output=True, text=True)
            
            if verify_result.returncode != 0:
                print("❌ Docker failed to start properly")
                return False
            
            return True
            
        except Exception as e:
            print(f"❌ Error configuring Docker daemon: {e}")
            return False
    
    def display_results_and_choose(self, results: List[Dict]) -> Optional[Dict]:
        """Display test results and let user choose which mirror to use"""
        print("=" * 60)
        print("📊 DOCKER REGISTRY MIRROR TEST RESULTS")
        print("=" * 60)
        
        # Sort by total score (lower is better)
        working_results = [r for r in results if r['status'] == 'Working']
        working_results.sort(key=lambda x: x['total_score'])
        
        if not working_results:
            print("❌ No working registry mirrors found!")
            
            # Show what we found
            print("\n📋 Test Summary:")
            for result in results:
                status_icon = "✅" if result['connectivity_success'] else "❌"
                hub_icon = "✅" if result['hub_success'] else "❌"
                print(f"  {status_icon} {result['name']}: {result['mirror']}")
                print(f"     Connectivity: {status_icon} | Docker Hub: {hub_icon}")
            
            return None
        
        print(f"{'#':<3} {'Registry':<15} {'Mirror':<35} {'Conn(s)':<8} {'Hub(s)':<8} {'Score':<8}")
        print("-" * 85)
        
        for i, result in enumerate(working_results, 1):
            conn_time = f"{result['connectivity_time']:.2f}" if result['connectivity_success'] else "Failed"
            hub_time = f"{result['hub_time']:.2f}" if result['hub_success'] else "Failed"
            score = f"{result['total_score']:.2f}" if result['status'] == 'Working' else "N/A"
            
            print(f"{i:<3} {result['name']:<15} {result['mirror']:<35} {conn_time:<8} {hub_time:<8} {score:<8}")
        
        # Show failed ones
        failed_results = [r for r in results if r['status'] != 'Working']
        if failed_results:
            print("\n❌ Failed Registry Mirrors:")
            for result in failed_results:
                print(f"   {result['name']}: {result['mirror']} - {result['status']}")
        
        # Show current configuration
        print("\n" + "=" * 60)
        print("📋 CURRENT DOCKER CONFIGURATION:")
        try:
            current_info = subprocess.run(['docker', 'info'], capture_output=True, text=True)
            if current_info.returncode == 0:
                lines = current_info.stdout.split('\n')
                for line in lines:
                    if 'Registry Mirrors:' in line:
                        print("🔗 Current Registry Mirrors:")
                        idx = lines.index(line)
                        for next_line in lines[idx+1:]:
                            if next_line.strip().startswith('http'):
                                print(f"   {next_line.strip()}")
                            elif next_line.strip() and not next_line.startswith(' '):
                                break
                        break
                else:
                    print("🔗 No registry mirrors currently configured")
        except:
            print("🔗 Could not read current configuration")
        
        print("=" * 60)
        print("🏆 FASTEST REGISTRY MIRROR:")
        best_mirror = working_results[0]
        print(f"📡 {best_mirror['name']}: {best_mirror['mirror']}")
        print(f"⚡ Score: {best_mirror['total_score']:.2f}s (Conn: {best_mirror['connectivity_time']:.2f}s + Hub: {best_mirror['hub_time']:.2f}s)")
        print("=" * 60)
        
        # Let user choose
        while True:
            print(f"\n🤔 Choose a registry mirror to configure:")
            print(f"   1-{len(working_results)}: Select from the working mirrors above")
            print("   0: Skip configuration (keep current)")
            print("   q: Quit without changes")
            
            choice = input("\nEnter your choice: ").strip().lower()
            
            if choice == 'q':
                print("⏹️  Configuration cancelled by user")
                return None
            elif choice == '0':
                print("⏭️  Configuration skipped, keeping current settings")
                return None
            else:
                try:
                    choice_num = int(choice)
                    if 1 <= choice_num <= len(working_results):
                        selected = working_results[choice_num - 1]
                        print(f"\n✅ You selected: {selected['name']} ({selected['mirror']})")
                        print(f"⚡ Performance: {selected['total_score']:.2f}s total (Conn: {selected['connectivity_time']:.2f}s + Hub: {selected['hub_time']:.2f}s)")
                        
                        confirm = input("\n🔄 Confirm configuration? (y/N): ").strip().lower()
                        if confirm in ['y', 'yes']:
                            return selected
                        else:
                            print("❌ Selection cancelled, choose again...")
                            continue
                    else:
                        print(f"❌ Invalid choice. Please enter a number between 1 and {len(working_results)}")
                except ValueError:
                    print("❌ Invalid input. Please enter a number, 0, or 'q'")
    
    def run_selection(self) -> bool:
        """Run the complete registry selection process"""
        # Check if Docker is installed and running
        try:
            subprocess.run(['docker', '--version'], check=True, capture_output=True)
            subprocess.run(['docker', 'info'], check=True, capture_output=True)
        except subprocess.CalledProcessError:
            print("❌ Docker is not installed or not running!")
            return False
        
        # Test all registries
        results = self.test_all_registries()
        
        # Display results and let user choose
        selected_mirror = self.display_results_and_choose(results)
        
        if not selected_mirror:
            return False
        
        # Configure the selected mirror
        print(f"\n⚙️  Configuring Docker to use {selected_mirror['name']}...")
        if self._configure_docker_daemon(selected_mirror):
            print("✅ Docker daemon configured successfully!")
            print("🔄 Docker daemon restarted")
            print(f"🎉 Now using registry mirror: {selected_mirror['mirror']}")
            
            # Test the configuration
            print("\n🧪 Testing new configuration...")
            test_result = subprocess.run(['docker', 'pull', 'hello-world:latest'], 
                                       capture_output=True, text=True)
            if test_result.returncode == 0:
                print("✅ Configuration test successful!")
                # Clean up test image
                subprocess.run(['docker', 'rmi', 'hello-world:latest'], 
                             capture_output=True, text=True)
            else:
                print("⚠️  Configuration test failed, but mirror is configured")
            
            return True
        else:
            print("❌ Failed to configure Docker daemon")
            return False

def main():
    """Main function"""
    print("🐳 Interactive Docker Registry Mirror Selector")
    print("=" * 50)
    
    # Check if running as root or with sudo
    if os.geteuid() != 0:
        print("❌ This script requires root privileges to modify Docker daemon configuration")
        print("Please run with: sudo python3 registry_selector_interactive.py")
        return 1
    
    try:
        selector = InteractiveRegistrySelector()
        success = selector.run_selection()
        return 0 if success else 1
        
    except KeyboardInterrupt:
        print("\n\n⏹️  Registry selection cancelled by user")
        return 1
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())

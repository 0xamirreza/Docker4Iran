#!/usr/bin/env python3
"""
DNS Selector for Docker Installation
Tests DNS servers for speed and reliability before Docker installation
"""

import json
import socket
import time
import subprocess
import sys
import os
import shutil
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Tuple, Optional

class DNSSelector:
    def __init__(self, dns_config_path: str = "conf/dns.json"):
        self.dns_config_path = dns_config_path
        self.dns_servers = self._load_dns_config()
        self.test_domains = [
            "google.com",
            "github.com", 
            "docker.com",
            "ubuntu.com"
        ]
        self.docker_domains = [
            "download.docker.com",
            "registry-1.docker.io",
            "auth.docker.io"
        ]
    
    def _load_dns_config(self) -> Dict:
        """Load DNS configuration from JSON file"""
        try:
            with open(self.dns_config_path, 'r') as f:
                config = json.load(f)
                return config.get('dns_servers', {})
        except FileNotFoundError:
            print(f"❌ DNS config file not found: {self.dns_config_path}")
            sys.exit(1)
        except json.JSONDecodeError:
            print(f"❌ Invalid JSON in DNS config file: {self.dns_config_path}")
            sys.exit(1)
    
    def _test_dns_resolution(self, dns_server: str, domain: str, timeout: int = 3) -> Tuple[bool, float]:
        """Test DNS resolution speed for a specific server and domain"""
        try:
            start_time = time.time()
            
            # Use nslookup to test DNS resolution
            result = subprocess.run(
                ['nslookup', domain, dns_server],
                capture_output=True,
                text=True,
                timeout=timeout
            )
            
            end_time = time.time()
            response_time = end_time - start_time
            
            # Check if resolution was successful
            if result.returncode == 0 and "NXDOMAIN" not in result.stdout:
                return True, response_time
            else:
                return False, float('inf')
                
        except (subprocess.TimeoutExpired, subprocess.SubprocessError):
            return False, float('inf')
        except Exception:
            return False, float('inf')
    
    def _test_docker_connectivity(self, dns_server: str, timeout: int = 5) -> Dict:
        """Test Docker-specific connectivity using a DNS server"""
        docker_results = {
            'docker_success_count': 0,
            'docker_total_time': 0,
            'docker_avg_time': float('inf'),
            'docker_success_rate': 0,
            'docker_working': False,
            'docker_details': []
        }
        
        successful_docker_tests = []
        
        for domain in self.docker_domains:
            success, response_time = self._test_dns_resolution(dns_server, domain, timeout)
            detail = {
                'domain': domain,
                'success': success,
                'time': response_time if success else 'timeout'
            }
            docker_results['docker_details'].append(detail)
            
            if success:
                docker_results['docker_success_count'] += 1
                successful_docker_tests.append(response_time)
        
        if successful_docker_tests:
            docker_results['docker_total_time'] = sum(successful_docker_tests)
            docker_results['docker_avg_time'] = docker_results['docker_total_time'] / len(successful_docker_tests)
            docker_results['docker_success_rate'] = (docker_results['docker_success_count'] / len(self.docker_domains)) * 100
            docker_results['docker_working'] = docker_results['docker_success_rate'] >= 66  # At least 2/3 Docker domains
        
        return docker_results
    
    def _test_dns_server(self, server_name: str, server_info: Dict) -> Dict:
        """Test a DNS server against multiple domains including Docker-specific ones"""
        primary_dns = server_info['primary']
        secondary_dns = server_info.get('secondary', '')
        
        print(f"🔍 Testing {server_name} ({primary_dns})...")
        
        results = {
            'name': server_name,
            'primary': primary_dns,
            'secondary': secondary_dns,
            'success_count': 0,
            'total_time': 0,
            'avg_time': float('inf'),
            'success_rate': 0,
            'working': False
        }
        
        successful_tests = []
        
        # Test primary DNS with general domains
        for domain in self.test_domains:
            success, response_time = self._test_dns_resolution(primary_dns, domain)
            if success:
                results['success_count'] += 1
                successful_tests.append(response_time)
        
        if successful_tests:
            results['total_time'] = sum(successful_tests)
            results['avg_time'] = results['total_time'] / len(successful_tests)
            results['success_rate'] = (results['success_count'] / len(self.test_domains)) * 100
            results['working'] = results['success_rate'] >= 50  # At least 50% success rate
        
        # Test Docker-specific connectivity
        docker_results = self._test_docker_connectivity(primary_dns)
        results.update(docker_results)
        
        return results
    
    def test_all_dns_servers(self, max_workers: int = 5) -> List[Dict]:
        """Test all DNS servers concurrently"""
        print("🚀 Starting DNS server testing...")
        print(f"📋 Testing {len(self.dns_servers)} DNS servers with {len(self.test_domains)} domains each")
        print("-" * 60)
        
        results = []
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all DNS tests
            future_to_server = {
                executor.submit(self._test_dns_server, name, info): name 
                for name, info in self.dns_servers.items()
            }
            
            # Collect results as they complete
            for future in as_completed(future_to_server):
                try:
                    result = future.result()
                    results.append(result)
                    
                    # Print immediate feedback
                    if result['working']:
                        print(f"✅ {result['name']}: {result['avg_time']:.2f}s avg, {result['success_rate']:.0f}% success")
                    else:
                        print(f"❌ {result['name']}: Failed or too slow")
                        
                except Exception as e:
                    server_name = future_to_server[future]
                    print(f"❌ {server_name}: Test failed - {str(e)}")
        
        return results
    
    def select_dns_interactive(self) -> Optional[Tuple[str, str]]:
        """Interactive DNS selection with Docker connectivity testing"""
        print("\n" + "="*70)
        print("🧪 DNS SERVER PERFORMANCE TEST (Docker Installation Focus)")
        print("="*70)
        
        results = self.test_all_dns_servers()
        
        # Filter working DNS servers
        working_servers = [r for r in results if r['working']]
        docker_working_servers = [r for r in results if r.get('docker_working', False)]
        
        if not working_servers:
            print("\n❌ No working DNS servers found!")
            return None
        
        # Sort by Docker performance first, then general performance
        working_servers.sort(key=lambda x: (not x.get('docker_working', False), x.get('docker_avg_time', float('inf')), x['avg_time']))
        
        print("\n📊 DNS SERVER TEST RESULTS:")
        print("=" * 70)
        print(f"{'#':<2} {'Name':<12} {'General':<15} {'Docker Connectivity':<25} {'IP Address':<15}")
        print("-" * 70)
        
        for i, server in enumerate(working_servers, 1):
            general_status = f"{server['avg_time']:.2f}s ({server['success_rate']:.0f}%)"
            
            if server.get('docker_working', False):
                docker_status = f"✅ {server['docker_avg_time']:.2f}s ({server['docker_success_rate']:.0f}%)"
            else:
                docker_status = "❌ Failed"
            
            print(f"{i:<2} {server['name']:<12} {general_status:<15} {docker_status:<25} {server['primary']:<15}")
        
        # Show Docker-specific details for top servers
        print("\n🐳 DOCKER CONNECTIVITY DETAILS:")
        print("-" * 70)
        for server in working_servers[:3]:
            if server.get('docker_details'):
                print(f"\n{server['name']} ({server['primary']}):")
                for detail in server['docker_details']:
                    status = "✅" if detail['success'] else "❌"
                    time_str = f"{detail['time']:.2f}s" if detail['success'] else "timeout"
                    print(f"  {status} {detail['domain']:<25} {time_str}")
        
        # Recommend best for Docker
        if docker_working_servers:
            best_docker = docker_working_servers[0]
            print(f"\n🏆 RECOMMENDED FOR DOCKER: {best_docker['name']} ({best_docker['primary']})")
            print(f"   Docker connectivity: {best_docker['docker_success_rate']:.0f}% success, {best_docker['docker_avg_time']:.2f}s avg")
            print(f"   General performance: {best_docker['success_rate']:.0f}% success, {best_docker['avg_time']:.2f}s avg")
        
        # Interactive selection
        print("\n" + "="*70)
        print("🎯 SELECT DNS SERVER:")
        while True:
            try:
                choice = input(f"Enter number (1-{len(working_servers)}) or 'q' to quit: ").strip().lower()
                
                if choice == 'q':
                    print("\n⏭️  DNS selection cancelled.")
                    return None
                
                choice_num = int(choice)
                if 1 <= choice_num <= len(working_servers):
                    selected = working_servers[choice_num - 1]
                    print(f"\n✅ SELECTED: {selected['name']} ({selected['primary']})")
                    
                    # Show what user selected
                    if selected.get('docker_working', False):
                        print(f"   ✅ Docker connectivity: {selected['docker_success_rate']:.0f}% success")
                    else:
                        print(f"   ⚠️  Docker connectivity: Limited (may cause download issues)")
                    
                    return selected['primary'], selected['secondary']
                else:
                    print(f"❌ Please enter a number between 1 and {len(working_servers)}")
                    
            except ValueError:
                print("❌ Please enter a valid number or 'q' to quit")
            except KeyboardInterrupt:
                print("\n\n⏭️  DNS selection cancelled.")
                return None
    
    def _is_systemd_resolved_active(self) -> bool:
        """Check if systemd-resolved is active and running."""
        if not shutil.which("resolvectl"): 
            return False
        try:
            status_output = subprocess.check_output(['resolvectl', 'status'], text=True, stderr=subprocess.DEVNULL)
            return "systemd-resolved is running" in status_output
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False

    def apply_dns_settings(self, primary_dns: str, secondary_dns: str) -> bool:
        """Apply DNS settings, detecting whether to use systemd-resolved or /etc/resolv.conf."""
        if self._is_systemd_resolved_active():
            print("ℹ️ systemd-resolved detected. Applying DNS settings via resolvectl...")
            return self._apply_dns_systemd_resolved(primary_dns, secondary_dns)
        else:
            print("ℹ️ Applying DNS settings via /etc/resolv.conf...")
            return self._apply_dns_resolv_conf(primary_dns, secondary_dns)

    def _apply_dns_systemd_resolved(self, primary_dns: str, secondary_dns: str) -> bool:
        """Apply DNS settings using systemd-resolved by creating a config file."""
        dns_servers = [primary_dns]
        if secondary_dns:
            dns_servers.append(secondary_dns)
        
        conf_dir = "/etc/systemd/resolved.conf.d"
        conf_file_path = os.path.join(conf_dir, "99-docker4iran-dns.conf")
        conf_content = f"[Resolve]\nDNS={' '.join(dns_servers)}\n"
        
        try:
            print(f"Creating systemd-resolved config file: {conf_file_path}")
            # Create directory if it doesn't exist
            subprocess.run(['sudo', 'mkdir', '-p', conf_dir], check=True)
            
            # Write new DNS settings to a temporary file
            tmp_conf_path = '/tmp/99-docker4iran-dns.conf'
            with open(tmp_conf_path, 'w') as f:
                f.write(conf_content)
            
            # Move the temporary file to the final destination with sudo
            subprocess.run(['sudo', 'cp', tmp_conf_path, conf_file_path], check=True)
            subprocess.run(['rm', tmp_conf_path], check=True)
            
            # Restart systemd-resolved to apply changes
            print("Restarting systemd-resolved service...")
            subprocess.run(['sudo', 'systemctl', 'restart', 'systemd-resolved'], check=True)
            
            print(f"✅ DNS settings applied successfully!")
            print(f"   Primary DNS: {primary_dns}")
            if secondary_dns:
                print(f"   Secondary DNS: {secondary_dns}")
            
            return True

        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to apply DNS settings for systemd-resolved: {e}")
            print(f"   Stderr: {e.stderr}")
            return False
        except Exception as e:
            print(f"❌ An unexpected error occurred: {e}")
            return False

    def _apply_dns_resolv_conf(self, primary_dns: str, secondary_dns: str) -> bool:
        """Apply DNS settings to /etc/resolv.conf (legacy method)."""
        try:
            resolv_conf_content = f"nameserver {primary_dns}\n"
            if secondary_dns:
                resolv_conf_content += f"nameserver {secondary_dns}\n"
            
            # Backup current resolv.conf
            subprocess.run(['sudo', 'cp', '/etc/resolv.conf', '/etc/resolv.conf.backup'], check=True)
            
            # Write new DNS settings
            with open('/tmp/resolv.conf.new', 'w') as f:
                f.write(resolv_conf_content)
            
            subprocess.run(['sudo', 'cp', '/tmp/resolv.conf.new', '/etc/resolv.conf'], check=True)
            subprocess.run(['rm', '/tmp/resolv.conf.new'], check=True)
            
            print(f"✅ DNS settings applied successfully!")
            print(f"   Primary DNS: {primary_dns}")
            if secondary_dns:
                print(f"   Secondary DNS: {secondary_dns}")
            
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to apply DNS settings: {e}")
            return False
        except Exception as e:
            print(f"❌ Error applying DNS settings: {e}")
            return False

def main():
    """Main function"""
    print("🔧 Docker Installation DNS Selector")
    print("="*50)
    
    # Change to script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    
    # Initialize DNS selector
    selector = DNSSelector()
    
    # Interactive DNS selection with Docker focus
    dns_result = selector.select_dns_interactive()
    
    if dns_result:
        primary_dns, secondary_dns = dns_result
        
        # Ask user if they want to apply the settings
        print(f"\n🤔 Apply DNS settings: {primary_dns}" + (f" & {secondary_dns}" if secondary_dns else "") + "?")
        response = input("   Apply for Docker installation? (y/N): ").lower().strip()
        
        if response in ['y', 'yes']:
            if selector.apply_dns_settings(primary_dns, secondary_dns):
                print("\n🎉 DNS settings applied! Ready for Docker installation.")
                print(f"\n🔧 Next steps:")
                print(f"   1. Test Docker connectivity: curl -I https://download.docker.com")
                print(f"   2. Run Docker installation: sudo ./unified_installer.sh")
                return 0
            else:
                print("\n❌ Failed to apply DNS settings")
                return 1
        else:
            print("\n⏭️  DNS settings not applied. Using system defaults.")
            print("\n⚠️  Warning: Docker installation may fail due to connectivity issues.")
            return 0
    else:
        print("\n❌ No suitable DNS server selected")
        print("   Proceeding with system default DNS...")
        return 1

if __name__ == "__main__":
    sys.exit(main())

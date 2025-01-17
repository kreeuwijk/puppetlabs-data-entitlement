require 'spec_helper'

describe 'data_entitlement::app_stack' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) { { 'dns_name' => 'data_entitlement.test.com', 'ui_use_tls' => false } }

      context 'with defaults' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_group('docker').with_ensure('present') }
        it { is_expected.to contain_class('docker').with_log_driver('journald') }
        it { is_expected.to contain_class('docker::compose').with_ensure('present') }
        it { is_expected.to contain_file('/opt/puppetlabs/data_entitlement').with_ensure('directory') }
        it {
          is_expected.to contain_docker_compose('data_entitlement')
            .with_compose_files(['/opt/puppetlabs/data_entitlement/docker-compose.yaml'])
            .that_requires('File[/opt/puppetlabs/data_entitlement/docker-compose.yaml]')
            .that_subscribes_to('File[/opt/puppetlabs/data_entitlement/docker-compose.yaml]')
        }
        it {
          is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
            .with_owner('root')
            .with_group('docker')
            .with_content(%r{NAME=data_entitlement\.test\.com})
            .with_content(%r{- "80:80"})
        }
        dir_list = [
          '/opt/puppetlabs/data_entitlement',
          '/opt/puppetlabs/data_entitlement/ssl',
        ]

        dir_list.each do |d|
          it {
            is_expected.to contain_file(d)
              .with_ensure('directory')
              .with_owner('11223')
              .with_group('11223')
          }
        end
      end

      context 'ui cert tests' do
        context 'with ui tls enabled' do
          let(:pre_condition) do
            <<-EOS
              file { "/tmp/ui-cert.key": ensure => present }
              file { "/tmp/ui-cert.pem": ensure => present }
            EOS
          end

          let(:params) do
            {
              'dns_name' => 'data_entitlement.test.com',
              'ui_use_tls' => true,
              'ui_cert_files_puppet_managed' => true,
              'ui_key_file' => '/tmp/ui-cert.key',
              'ui_cert_file' => '/tmp/ui-cert.pem',
            }
          end

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_docker_compose('data_entitlement')
              .with_compose_files(['/opt/puppetlabs/data_entitlement/docker-compose.yaml'])
              .that_requires(
                [
                  'File[/tmp/ui-cert.key]',
                  'File[/tmp/ui-cert.pem]',
                  'File[/opt/puppetlabs/data_entitlement/docker-compose.yaml]',
                ],
              )
              .that_subscribes_to(
                [
                  'File[/tmp/ui-cert.key]',
                  'File[/tmp/ui-cert.pem]',
                  'File[/opt/puppetlabs/data_entitlement/docker-compose.yaml]',
                ],
              )
          }
          it {
            is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
              .with_content(%r{- "80:80"})
              .with_content(%r{- "443:443"})
          }
        end

        context 'with ui tls enabled - default key and cert' do
          let(:params) do
            {
              'dns_name' => 'data_entitlement.test.com',
              'ui_use_tls' => true,
            }
          end
          let(:node) { 'data_entitlement.example' }

          ## Make sure this isn't data_entitlement-test
          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_docker_compose('data_entitlement')
              .with_compose_files(['/opt/puppetlabs/data_entitlement/docker-compose.yaml'])
              .that_requires(
                [
                  'File[/opt/puppetlabs/data_entitlement/docker-compose.yaml]',
                ],
              )
              .that_subscribes_to(
                [
                  'File[/opt/puppetlabs/data_entitlement/docker-compose.yaml]',
                ],
              )
          }
          it {
            is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
              .with_content(%r{- "80:80"})
              .with_content(%r{- "443:443"})
              .with_content(%r{- ".*data_entitlement\.example.*:/etc/ssl/key\.pem:ro"})
              .with_content(%r{- ".*data_entitlement\.example.*:/etc/ssl/cert\.pem:ro"})
          }
        end

        context 'with ui_ca_cert_file specified' do
          let(:pre_condition) do
            <<-EOS
              file { "/tmp/ui-ca.pem": ensure => present }
              file { "/tmp/ui-cert.key": ensure => present }
              file { "/tmp/ui-cert.pem": ensure => present }
            EOS
          end

          let(:params) do
            {
              'dns_name' => 'data_entitlement.test.com',
              'ui_use_tls' => true,
              'ui_cert_files_puppet_managed' => true,
              'ui_ca_cert_file' => '/tmp/ui-ca.pem',
              'ui_key_file' => '/tmp/ui-cert.key',
              'ui_cert_file' => '/tmp/ui-cert.pem',
            }
          end

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_docker_compose('data_entitlement')
              .with_compose_files(['/opt/puppetlabs/data_entitlement/docker-compose.yaml'])
              .that_requires(
                [
                  'File[/tmp/ui-ca.pem]',
                  'File[/tmp/ui-cert.key]',
                  'File[/tmp/ui-cert.pem]',
                  'File[/opt/puppetlabs/data_entitlement/docker-compose.yaml]',
                ],
              )
              .that_subscribes_to(
                [
                  'File[/tmp/ui-ca.pem]',
                  'File[/tmp/ui-cert.key]',
                  'File[/tmp/ui-cert.pem]',
                  'File[/opt/puppetlabs/data_entitlement/docker-compose.yaml]',
                ],
              )
          }
        end

        context 'with host cert' do
          let(:pre_condition) do
            <<-EOS
              file { "/tmp/ui-ca.pem": ensure => present }
              file { "/tmp/ui-cert.key": ensure => present }
              file { "/tmp/ui-cert.pem": ensure => present }
            EOS
          end
          let(:trusted_facts) { { 'certname' => 'true.data_entitlement' } }
          let(:node) { 'true.data_entitlement' }
          let(:params) do
            {
              'dns_name' => 'true.data_entitlement',
              'ui_use_tls' => true,
              'ui_cert_files_puppet_managed' => false,
              'ui_ca_cert_file' => '/tmp/ui-ca.pem',
            }
          end

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_docker_compose('data_entitlement')
              .with_compose_files(['/opt/puppetlabs/data_entitlement/docker-compose.yaml'])
          }
          it { is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml').with_content(%r{- \"/etc/puppetlabs/puppet/ssl/private_keys/true\.data_entitlement\.pem:/etc/ssl/key\.pem:ro\"}) }
          it { is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml').with_content(%r{- \"/etc/puppetlabs/puppet/ssl/certs/true\.data_entitlement\.pem:/etc/ssl/cert\.pem:ro\"}) }
        end
      end

      context 'with seperate versions' do
        let(:params) do
          {
            'dns_name' => 'data_entitlement.test.com',
            'image_repository' => 'hub.docker.com',
            'image_prefix' => '',
            'data_entitlement_version' => 'foo',
            'ui_version' => 'bar',
            'frontend_version' => 'baz',
          }
        end

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
            .with_owner('root')
            .with_group('docker')
            .with_content(%r{hub.docker.com/data-ingestion:foo})
            .with_content(%r{hub.docker.com/ui:bar})
            .with_content(%r{hub.docker.com/ui-frontend:baz})
        }
      end

      context 'with same versions' do
        let(:params) do
          {
            'dns_name' => 'data_entitlement.test.com',
            'image_repository' => 'hub.docker.com',
            'image_prefix' => '',
            'data_entitlement_version' => 'foo',
          }
        end

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
            .with_owner('root')
            .with_group('docker')
            .with_content(%r{hub.docker.com/data-ingestion:foo})
            .with_content(%r{hub.docker.com/ui:foo})
            .with_content(%r{hub.docker.com/ui-frontend:foo})
        }
      end
      context 'with super version' do
        let(:params) do
          {
            'dns_name' => 'data_entitlement.test.com',
            'image_repository' => 'hub.docker.com',
            'image_prefix' => '',
            'version' => 'baz',
          }
        end

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
            .with_owner('root')
            .with_group('docker')
            .with_content(%r{hub.docker.com/data-ingestion:baz})
            .with_content(%r{hub.docker.com/ui:baz})
            .with_content(%r{hub.docker.com/ui-frontend:baz})
        }
      end

      context 'data_entitlement admin config options' do
        context 'set prometheus namespace' do
          let(:params) do
            {
              'dns_name' => 'data_entitlement.test.com',
              'prometheus_namespace' => 'foo',
            }
          end

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
              .with_content(%r{- "HDP_ADMIN_PROMETHEUS_NAMESPACE=foo"})
          }
        end

        context 'set access log level - non-default' do
          let(:params) do
            {
              'dns_name' => 'data_entitlement.test.com',
              'access_log_level' => 'all',
            }
          end

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
              .with_content(%r{- "HDP_ADMIN_ACCESS_LOG_LEVEL=all"})
          }
        end

        context 'set access log level - default' do
          let(:params) do
            {
              'dns_name' => 'data_entitlement.test.com',
            }
          end

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
              .with_content(%r{- "HDP_ADMIN_ACCESS_LOG_LEVEL=admin"})
          }
        end
      end

      context 'extra hosts' do
        context 'set extra hosts' do
          let(:params) do
            {
              'dns_name' => 'data_entitlement.test.com',
              'prometheus_namespace' => 'foo',
              'extra_hosts' => { 'foo' => '127.0.0.1', 'bar' => '1.1.1.1' },
            }
          end

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
              .with_content(%r{extra_hosts:})
          }
          it {
            is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
              .with_content(%r{foo:127\.0\.0\.1})
          }
          it {
            is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
              .with_content(%r{bar:1\.1\.1\.1})
          }
        end

        context 'no extra hosts' do
          let(:params) do
            {
              'dns_name' => 'data_entitlement.test.com',
              'prometheus_namespace' => 'foo',
              'extra_hosts' => {},
            }
          end

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
              .without_content(%r{extra_hosts:})
          }
        end
      end

      context 'infra images' do
        context 'redis' do
          context 'default' do
            let(:params) do
              {
                'dns_name' => 'data_entitlement.test.com',
              }
            end

            it { is_expected.to compile.with_all_deps }
            it {
              is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
                .with_content(%r{image: "redis:6.2.4-buster"}) ## Tests will break if image updates. Good or bad? Leaning good.
            }
          end
          context 'set' do
            let(:params) do
              {
                'dns_name' => 'data_entitlement.test.com',
                'redis_image' => 'test/redis:latest',
              }
            end

            it { is_expected.to compile.with_all_deps }
            it {
              is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
                .with_content(%r{image: "test/redis:latest"})
            }
          end
        end

        context 'elasticsearch' do
          context 'default' do
            let(:params) do
              {
                'dns_name' => 'data_entitlement.test.com',
              }
            end

            it { is_expected.to compile.with_all_deps }
            it {
              is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
                .with_content(%r{image: "docker.elastic.co/elasticsearch/elasticsearch-oss:7.10.1"})
            }
          end
          context 'set' do
            let(:params) do
              {
                'dns_name' => 'data_entitlement.test.com',
                'elasticsearch_image' => 'test/es:latest',
              }
            end

            it { is_expected.to compile.with_all_deps }
            it {
              is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
                .with_content(%r{image: "test/es:latest"})
            }
          end
        end

        context 'minio' do
          context 'default' do
            let(:params) do
              {
                'dns_name' => 'data_entitlement.test.com',
              }
            end

            it { is_expected.to compile.with_all_deps }
            it {
              is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
                .with_content(%r{image: "minio/minio:RELEASE.2021-04-22T15-44-28Z"})
            }
          end
          context 'set' do
            let(:params) do
              {
                'dns_name' => 'data_entitlement.test.com',
                'minio_image' => 'test/minio:latest',
              }
            end

            it { is_expected.to compile.with_all_deps }
            it {
              is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
                .with_content(%r{image: "test/minio:latest"})
            }
          end
        end
      end

      context 'auth' do
        context 'default' do
          let(:params) do
            {
              'dns_name' => 'data_entitlement.test.com',
            }
          end

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
              .without_content(%r{HDP_HTTP_QUERY_USER=})
              .without_content(%r{HDP_HTTP_QUERY_PASSWORD=})
              .without_content(%r{HDP_HTTP_QUERY_SSO_ISSUER=})
              .without_content(%r{HDP_HTTP_QUERY_SSO_CLIENTID=})
              .without_content(%r{HDP_HTTP_QUERY_SSO_AUDIENCE=})
              .without_content(%r{REACT_APP_SSO_ISSUER=})
              .without_content(%r{REACT_APP_SSO_CLIENT_ID=})
          }
        end
        context 'oidc' do
          let(:params) do
            {
              'dns_name' => 'data_entitlement.test.com',
              'data_entitlement_query_auth' => 'oidc',
              'data_entitlement_query_oidc_issuer' => 'foo',
              'data_entitlement_query_oidc_client_id' => 'bar',
            }
          end

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
              .without_content(%r{HDP_HTTP_QUERY_USER=})
              .without_content(%r{HDP_HTTP_QUERY_PASSWORD=})
              .with_content(%r{HDP_HTTP_QUERY_SSO_ISSUER=foo})
              .with_content(%r{HDP_HTTP_QUERY_SSO_CLIENTID=bar})
              .with_content(%r{REACT_APP_SSO_ISSUER=foo})
              .with_content(%r{REACT_APP_SSO_CLIENT_ID=bar})
          }
        end
        context 'pe_rbac - defaults' do
          let(:params) do
            {
              'dns_name' => 'data_entitlement.test.com',
              'data_entitlement_query_auth' => 'pe_rbac',
              'data_entitlement_query_pe_rbac_service' => 'https://puppet:4433/rbac-api',
            }
          end

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
              .without_content(%r{HDP_HTTP_QUERY_USER=})
              .without_content(%r{HDP_HTTP_QUERY_PASSWORD=})
              .with_content(%r{HDP_HTTP_QUERY_PE_RBAC_SERVICE_LOCATION=https://puppet:4433/rbac-api})
              .with_content(%r{HDP_HTTP_QUERY_PE_RBAC_ROLE_ID=1})
              .with_content(%r{HDP_HTTP_QUERY_PE_RBAC_CA_CERT_FILE=/etc/puppetlabs/puppet/ssl/certs/ca\.pem})
          }
        end
        context 'pe_rbac - specified, system CA' do
          let(:params) do
            {
              'dns_name' => 'data_entitlement.test.com',
              'data_entitlement_query_auth' => 'pe_rbac',
              'data_entitlement_query_pe_rbac_service' => 'https://puppet:4433/rbac-api',
              'data_entitlement_query_pe_rbac_role_id' => 2,
              'data_entitlement_query_pe_rbac_ca_cert_file' => '-',
            }
          end

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
              .without_content(%r{HDP_HTTP_QUERY_USER=})
              .without_content(%r{HDP_HTTP_QUERY_PASSWORD=})
              .with_content(%r{HDP_HTTP_QUERY_PE_RBAC_SERVICE_LOCATION=https://puppet:4433/rbac-api})
              .with_content(%r{HDP_HTTP_QUERY_PE_RBAC_ROLE_ID=2})
              .without_content(%r{HDP_HTTP_QUERY_PE_RBAC_CA_CERT_FILE})
          }
        end
        context 'basic - specified' do
          let(:params) do
            {
              'dns_name' => 'data_entitlement.test.com',
              'data_entitlement_query_auth' => 'basic_auth',
              'data_entitlement_query_username' => 'super-user',
              'data_entitlement_query_password' => sensitive('admin-password'),
            }
          end

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
              .with_content(%r{- "HDP_HTTP_QUERY_USER=super-user"})
              .with_content(%r{- "HDP_HTTP_QUERY_PASSWORD=admin-password"})
              .without_content(%r{HDP_HTTP_QUERY_SSO_ISSUER=})
              .without_content(%r{HDP_HTTP_QUERY_SSO_CLIENTID=})
              .without_content(%r{HDP_HTTP_QUERY_SSO_AUDIENCE=})
              .without_content(%r{REACT_APP_SSO_ISSUER=})
              .without_content(%r{REACT_APP_SSO_CLIENT_ID=})
          }
        end

        context 'basic - specified hash' do
          let(:params) do
            {
              'dns_name' => 'data_entitlement.test.com',
              'data_entitlement_query_auth' => 'basic_auth',
              'data_entitlement_query_username' => 'super-user',
              'data_entitlement_query_password' => sensitive('$6$foo$bar'),
            }
          end

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
              .with_content(%r{- "HDP_HTTP_QUERY_USER=super-user"})
              .with_content(%r{- "HDP_HTTP_QUERY_PASSWORD=\$\$6\$\$foo\$\$bar"})
              .without_content(%r{HDP_HTTP_QUERY_SSO_ISSUER=})
              .without_content(%r{HDP_HTTP_QUERY_SSO_CLIENTID=})
              .without_content(%r{HDP_HTTP_QUERY_SSO_AUDIENCE=})
              .without_content(%r{REACT_APP_SSO_ISSUER=})
              .without_content(%r{REACT_APP_SSO_CLIENT_ID=})
          }
        end
        context 'basic - old behavior' do
          let(:params) do
            {
              'dns_name' => 'data_entitlement.test.com',
              'data_entitlement_query_username' => 'super-user',
              'data_entitlement_query_password' => sensitive('admin-password'),
            }
          end

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
              .with_content(%r{- "HDP_HTTP_QUERY_USER=super-user"})
              .with_content(%r{- "HDP_HTTP_QUERY_PASSWORD=admin-password"})
              .without_content(%r{HDP_HTTP_QUERY_SSO_ISSUER=})
              .without_content(%r{HDP_HTTP_QUERY_SSO_CLIENTiD=})
              .without_content(%r{HDP_HTTP_QUERY_SSO_AUDIENCE=})
              .without_content(%r{REACT_APP_SSO_ISSUER=})
              .without_content(%r{REACT_APP_SSO_CLIENT_ID=})
          }
        end
      end
      context 'dashboard url' do
        let(:params) do
          {
            'dns_name' => 'data_entitlement.test.com',
            'dashboard_url' => 'https://foo.com',
          }
        end

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
            .with_content(%r{HDP_JOBS_DASHBOARD_URL=https://foo\.com})
        }
      end
      context 'docker data dir' do
        let(:params) do
          {
            'dns_name' => 'data_entitlement.test.com',
            'data_dir' => '/opt/puppetlabs/data_entitlement/volumes',
          }
        end

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
        }
      end
      context 'trust-on-first-use failures' do
        context 'Nothing specified' do
          let(:params) do
            {
              'dns_name' => 'data_entitlement.test.com',
              'allow_trust_on_first_use' => false,
              ## if ^ is false, we should fail compilation if certs keys and whatnot are not set.
            }
          end

          it { is_expected.to compile.and_raise_error(%r{.*}) }
        end
        context 'All specified' do
          let(:params) do
            {
              'dns_name' => 'data_entitlement.test.com',
              'allow_trust_on_first_use' => false,
              'ca_cert_file' => '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
              'cert_file' => '/etc/puppetlabs/puppet/ssl/certs/data_entitlement.test.com.pem',
              'key_file' => '/etc/puppetlabs/puppet/ssl/private_keys/data_entitlement.test.com.pem',
            }
          end

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_file('/opt/puppetlabs/data_entitlement/docker-compose.yaml')
              .with_content(%r{- "HDP_HTTP_UPLOAD_CACERTFILE=/etc/puppetlabs/puppet/ssl/certs/ca\.pem"})
              .with_content(%r{- "HDP_HTTP_UPLOAD_CERTFILE=/etc/puppetlabs/puppet/ssl/certs/data_entitlement\.test\.com\.pem"})
              .with_content(%r{- "HDP_HTTP_UPLOAD_KEYFILE=/etc/puppetlabs/puppet/ssl/private_keys/data_entitlement\.test\.com\.pem"})
          }
        end
      end
    end
  end
end

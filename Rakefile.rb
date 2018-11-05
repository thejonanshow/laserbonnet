require 'yaml'
@setup = YAML::load_file('/boot/setup.yaml')

desc "decrypt config"
task :decryptconfig do
  `gpg --yes -r "#{@setup["key"]["uid"]}" -o #{File.join(__dir__, 'config', 'production.yaml')} -d #{File.join(__dir__, 'config', 'production.yaml.enc')}`
end

desc "encypt config"
task :encryptconfig do
  `gpg --yes -r "#{@setup["key"]["uid"]}" -o #{File.join(__dir__, 'config', 'production.yaml.enc')} -e #{File.join(__dir__, 'config', 'production.yaml')}`
end

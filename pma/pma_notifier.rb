require 'rubygems'

require 'net/http'
require 'json'
require 'logger'
require 'syslog'

log = Logger.new(STDOUT)

pmshost = 'a3.xpne.info'
pmahost = 'a3.xpne.info'

#pmshost = 'ec2-46-51-229-175.ap-northeast-1.compute.amazonaws.com'
#pmahost = 'ec2-46-51-229-175.ap-northeast-1.compute.amazonaws.com'

Syslog.open();
Syslog.info('start pma_notifier');
log.info("start pma_notifer")
if File.exist?("/tmp/.pmalock") then
  Syslog.info('still run ');
  log.warn("still run")
  Syslog.info('exit pma_notifier');
  log.info("exit pma_notifier")
  exit;
end

#installDomains = Dir::entries('/var/www/sites/') - ['.', '..', 'kick.smt.cqc.jp', 'PNEManagerServer', 'smt.cqc.jp', 'timeline.cqc.jp', 'pne.cqc.jp', 'symfony2.cqc.jp', 'cqc.jp', '_back_pne.cqc.jp', 'download?v=Symfony_Standard_Vendors_2.1.7.tgz']

installDomains = Dir::entries('/var/www/sites/') - ['.', '..', pmshost]

http = Net::HTTP.new(pmshost, 80)

res = http.request_post('/api/server/update', 'host='+pmahost+'&domain='+installDomains.to_json)

puts res.body

Syslog.info('end pma_notifier');
log.info("end pma_notifier")

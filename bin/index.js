#!/usr/bin/env node
;(function () { // wrapper in case we're in module_context mode

  var log = require('npmlog')
  require('coffee-script/register');
  process.title = 'livingdocs';

  var action = process.argv.slice(2, 3)[0];
  var conf = require('minimist')(process.argv.slice(3), {
    alias: {
      v: 'verbose',
      verbose: 'verbose'
    }
  })

  log.level = 'info';
  if (conf.verbose) log.level = 'verbose';

  log.verbose('using', 'node@%s', process.version)
  log.verbose('cli', process.argv)
  log.verbose('cli', 'action', action)
  log.verbose('cli', 'options', conf)


  // Error handlers
  process.on('SIGTERM', function(err){
    if (err) log.error('cli', err);
    process.exit(1);
  });

  process.on('uncaughtException', function(err){
    log.error('cli', err);
    process.exit(1);
  });

  process.on('exit', function(){
    uptime = process.uptime();
    log.verbose("cli", "exit script. It ran for %ss.", parseInt(uptime))
  });


  commands = require('./commands');
  commands.init(conf, function (err) {
    if (err) return log.error('cli', err);
    commands.trigger(action, conf);
  });
})()

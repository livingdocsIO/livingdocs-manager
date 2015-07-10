var path = require('path');
var rc = require('rc');
var fs = require('fs');

var defaultConfig = {
	// Application Data Directory
	dir: path.join(require('os-homedir')(), '.config', 'livingdocs'),

	host: 'https://api.livingdocs.io',
	user: process.env.USER+'@upfront.io'
};

var config = rc('livingdocs', defaultConfig);
config.cache = path.join(config.dir, 'cache');

try {
	fs.mkdirSync(config.dir);
	fs.mkdirSync(config.cache);
} catch (err) {
	if (err && err.code != 'EEXIST') {
		var log = require('npmlog');
		log.error('cli', err);
	}
}

module.exports = config;

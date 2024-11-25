// Notes: https://github.com/rozek/notes-on-gundb
;(function(){
	var cluster = require('cluster');
	if(cluster.isMaster){
    console.info(`[UNIMATRIX] starting...`);
	  return cluster.fork() && cluster.on('exit', function(){ 
      cluster.fork(); 
      console.info(`[UNIMATRIX] exit`);
    });
	}

	var fs = require('fs');
	var path = require('path');
	var config = {
		port: process.env.OPENSHIFT_NODEJS_PORT || process.env.VCAP_APP_PORT || process.env.PORT || process.argv[2] || 8765,
		peers: process.env.PEERS && process.env.PEERS.split(',') || [],
	};
	const wwwDir=process.env.WWW || path.join(__dirname, 'www');
	var Gun = require('gun');	
	const staticMiddleware=Gun.serve(wwwDir);	
	if(process.env.HTTPS_KEY){
		config.key = fs.readFileSync(process.env.HTTPS_KEY);
		config.cert = fs.readFileSync(process.env.HTTPS_CERT);
		config.server = require('https').createServer(config, staticMiddleware);
    		console.info(`[UNIMATRIX] using SSL`);
	} else {
		config.server = require('http').createServer(staticMiddleware);
	}
	var cfg = {
    		debug:process.env.DEBUG,
    		gunRoute:process.env.ROUTE || '/gun',
    		wwwDir,
		...config,
	};	
	if(!!cfg.debug)
      		console.dir({cfg,__dirname});	
	if(cfg.wwwDir){
    		console.info(`[UNIMATRIX] serving ${cfg.wwwDir}`);
  	}
	
	var gun = Gun({web: config.server.listen(cfg.port), peers: cfg.peers});

	console.info(`[UNIMATRIX] Relay peer started on port ${cfg.port} with ${cfg.gunRoute}`);
	module.exports = gun;
}());

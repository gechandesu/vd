module main

import flag
import log
import net.http.file
import os
import rand
import v.vmod

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('vdocserve')
	fp.description('generate and serve V module HTML documentation')
	fp.version('0.1.0')
	fp.skip_executable()
	fp.limit_free_args(0, 2)!
	listen := fp.string('listen', u8(`l`), '127.0.0.1:4000', 'HTTP server listen address:port')
	fp.finalize() or {
		eprintln(err)
		println(fp.usage())
		exit(1)
	}
	mut cache := vmod.get_cache()
	modfile := cache.get_by_folder(os.getwd())
	modname := vmod.from_file(modfile.vmod_file)!.name
	docs_dir := os.join_path(os.temp_dir(), os.geteuid().str(), modname + '_docs_' +
		rand.u16().hex())
	log.info('generating HTML docs in temporary dir ${docs_dir}')
	os.mkdir_all(docs_dir, mode: 0o755)!
	os.execute_or_exit('v doc -f html -o ${docs_dir} -m . ')
	sigint_callback := fn [docs_dir] (_ os.Signal) {
		os.rmdir_all(docs_dir) or {
			log.error('unable to delete temporary dir ${docs_dir}')
			exit(1)
		}
		eprintln('cleanup temporary data')
		exit(0)
	}
	os.signal_opt(.int, sigint_callback)!
	log.info('starting docs server, use ^C to quit')
	file.serve(folder: docs_dir, index_file: modname + '.html', on: listen)
}

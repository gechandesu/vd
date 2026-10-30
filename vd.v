module main

import flag
import log
import net.http.file
import os
import os.cmdline
import rand
import v.vmod

struct Flags {
mut:
	help   bool
	listen string = '127.0.0.1:4000' @[short: l]
	dir    string                    @[ignore]
	opts   []string                  @[short: o]
}

fn main() {
	mut flags, no_matches := flag.to_struct[Flags](os.args, skip: 1, style: .go_flag) or {
		eprintln('cmdline parsing error, see -help for info')
		exit(2)
	}
	if no_matches.len == 0 {
		flags.dir = '.'
	} else if no_matches.len == 1 {
		flags.dir = no_matches[0]
	} else {
		eprintln('unrecognized arguments: ${no_matches[1..]}')
		exit(2)
	}
	if flags.help {
		println('Generate and serve HTML documentation for V module')
		println('')
		println('Usage: vd [-l addr:port] [-o <options>]... [<dir>]')
		println('')
		println('Options:')
		println('  -help        Print this help message and exit.')
		println('  -l, -listen  Listen address, 127.0.0.1:4000 by default.')
		println('  -o           Extra v doc options, can be set multiple times.')
		println('               Values with multiple words must be quoted.')
		exit(0)
	}
	mut cache := vmod.get_cache()
	modfile := cache.get_by_folder(os.getwd())
	modname := vmod.from_file(modfile.vmod_file)!.name
	tmp_dir := os.join_path(os.temp_dir(), os.geteuid().str(), modname + '_docs_' + rand.u32().hex())
	log.info('generate HTML docs...')
	os.mkdir_all(tmp_dir, mode: 0o755)!
	mut command := ['v', 'doc', '-f', 'html', '-o', tmp_dir, '-m', flags.dir]
	for opts in flags.opts {
		command << cmdline.split(opts) or { continue }
	}
	log.info('Run: ${command.join(' ')}')
	os.exec_or_exit(command)
	signal_callback := fn [tmp_dir] (_ os.Signal) {
		eprintln('\rCleanup...')
		os.rmdir_all(tmp_dir) or {
			log.error('unable to delete temporary dir ${tmp_dir}')
			exit(1)
		}
		exit(0)
	}
	os.signal_opt(.int, signal_callback)!
	os.signal_opt(.term, signal_callback)!
	log.info('docs stored in temporary dir ${tmp_dir}')
	log.info('use ^C to quit server')
	file.serve(folder: tmp_dir, index_file: modname + '.html', on: flags.listen)
}

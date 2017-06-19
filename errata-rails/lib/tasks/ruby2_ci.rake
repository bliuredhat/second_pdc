namespace:ruby2 do
  task :ci => 'ci:all'

  namespace :ci do
    task :all => [:test, :docs]

    task :test => ['test:all']
    task :docs => ['docs:all']


    namespace :test do
      task all: ['parallel:setup', :run]
      task run: [:run_test, 'parallel:features']

      task :setup_env do
        ENV['COVERAGE'] = '1'
        ENV['CI_REPORTS'] = 'test/reports'
        ENV['RECORD_RUNTIME'] = '1'
      end

      task run_test: :setup_env do
        test_opts = ENV['TESTOPTS'] || '-v'
        Rake::Task['parallel:test'].invoke(
          ENV['PARALLEL_TEST_THREADS'],
          nil,
          test_opts
        )
      end
    end

    namespace :docs do
      multitask :all => [:publican, :api]

      def prefix_sh_output(command, prefix)
        "set -o pipefail && stdbuf -oL -eL #{command} 2>&1 | sed -u -e 's/^/[#{prefix}] /'"
      end

      # The publican tasks depend on "environment", so they need to have a
      # DB prepared before running.
      task :publican => ['parallel:setup'] do
        sh prefix_sh_output('rake publican:release_note_init BOOK=Release_Notes', 'rel_note_prep')
        sh prefix_sh_output('rake publican:all_books DO=build_all_only HTML_ONLY=1', 'publican')
      end

      task :api do
        sh prefix_sh_output('rake apidocs:build', 'apidocs')
      end
    end
  end
end

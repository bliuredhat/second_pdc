#
# Generate content for pasting in to Confluence
#
namespace :wiki_content do
  #
  # Todo (maybe):
  #   - Lookup names in LDAP
  #   - Update confluence directly (?)
  #
  desc "Mailto Links"
  task :mailto_links do |t|
    view_html_template("mailto_links",

      :names => {
        'jmcdonal'          => 'Jason McDonald',
        'jorris'            => 'Jon Orris',
        'sbaird'            => 'Simon Baird',
        'rjoost'            => 'Róman Joost',
        'rmcgover'          => 'Rohan McGovern',
        'hyu'               => 'Hao Yu',
        'nadams'            => 'Neil Adams',
        'jinzhang'          => 'Joyce Zhang',
        'qgong'             => 'Qiang Gong',
        'jingwang'          => 'Jing Wang',
        'szhou'             => 'Shirley Zhou',
        'rbiba'             => 'Radek Biba',

        'errata-dev-list'   => 'Errata Dev List',
        'eng-announce-list' => 'Eng Announce List',
        'hss-list'          => 'HSS List',
        'qe-dept-list'      => 'QE Dept List',
        'eng-infra-list'    => 'Eng Infra List',
        'P360-dev-list'     => 'P360 Dev List',

        'eng-ops'           => 'Eng Ops',
        'acosta'            => 'AJ Costa',
        'abourne'           => 'Arlinton Bourne',
        'mgrigull'          => 'Marco Grigull',
        'bgroh'             => 'Bernd Groh',
        'ggillies'          => 'Graeme Gillies',
        'mkeir'             => 'Mark Keir',
        'cmedeiro'          => 'Caetano Medeiros',
        'desxu'             => 'Desong Xu',
      },

      :groups => [
        ['Developers only',        %w'jmcdonal jorris sbaird rjoost rmcgover hyu'],
        # Let's consider Radek an honorary team member..
        ['Entire team',            %w'jmcdonal jorris sbaird rjoost rmcgover hyu nadams jinzhang qgong jingwang szhou rbiba'],
      ],

      :announcements => [
        ['Release Announcements',  %w'eng-announce-list errata-dev-list eng-infra-list hss-list qe-dept-list'],
        ['Schema Updates',         %w'errata-dev-list P360-dev-list bgroh ggillies mkeir desxu'],
        # We spam quite a lot of eng-ops guys, hope they don't mind..
        ['Deploy Requests',        %w'eng-ops acosta mgrigull abourne mkeir cmedeiro jmcdonal jorris sbaird rjoost rmcgover hyu nadams jinzhang qgong jingwang szhou rbiba'],
      ],

      :task => t
    )

  end

  desc "Bug links"
  task :bug_links => [:ensure_local_kerb_ticket, :environment, :development_only] do |t|
    render_template_to_public('bug_links.md')
    puts "Wrote markdown to public/bug_links.md"
    unless ENV['NOPANDOC'] == '1'
      render_markdown_to_html_file('public/bug_links.md')
      puts "Wrote html to public/bug_links.md.html"
    end
  end

end

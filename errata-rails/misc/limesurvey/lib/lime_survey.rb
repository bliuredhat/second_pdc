require 'erb'
require 'ostruct'

class LimeSurvey
  def self.go(&block)
    s = self.new
    s.instance_eval(&block)
  end

  def initialize
    preamble
    @q_index = 0
    @answer_groups = {}
  end

  def answers(label_sym, answers_text)
    @answer_groups[label_sym.to_sym] = answers_text
  end

  def section(name)
    render 'section', :name => name
  end

  def question(text, answers, opts={})
    render 'question', :code => next_code, :text => text, :other => opts[:other]
    answers = @answer_groups[answers] if answers.is_a?(Symbol)
    answers.strip.split("\n").map(&:strip).each_with_index do |answer, index|
      render 'answer', :text => answer, :index => index
    end
  end

  def text_question(text, help=nil)
    render 'text_question', :code => next_code, :text => text, :help => help
  end

  def preamble
    print File.read('lib/preamble.tsv')
  end

  def render(partial, locals)
    print ERB.new(File.read("lib/#{partial}.tsv.erb")).result(OpenStruct.new(locals).send(:binding))
  end

  def next_code
    "Q#{@q_index+=1}"
  end

end

def survey(&block)
  LimeSurvey.go(&block)
end

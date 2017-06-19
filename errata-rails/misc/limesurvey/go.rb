#!/usr/bin/ruby -Ilib -rlime_survey
#
# LimeSurvey is located at:
#   https://survey.app.test.eng.nay.redhat.com/index.php/admin
#
# See here for a guide on using LimeSurvey:
#   https://docs.engineering.redhat.com/x/uSTHAQ
#
# Questions drafted here:
#   http://errata-dev.etherpad.corp.redhat.com/63
#
# Running `ruby go.rb` should output a tab delimited text that can
# be imported into LimeSurvey.
#
# Notes:
# - Be careful to not strip the trailing tabs in the templates. They are
#   probably required.
# - Editing the introduction text and other survey options might be better
#   done in the LimeSurvey admin UI.
# - There are many different questions types options in LimeSurvey that the
#   DSL doesn't support.
#
survey {

  answers :agree, %{
    Strongly disagree
    Disagree
    Neither agree nor disagree
    Agree
    Strongly agree
    Don't know
  }

  answers :useful, %{
    Almost useless
    Somewhat useless
    Occasionally useful
    Useful
    Very useful
    Don't know
  }

  answers :yes_no, %{
    Yes
    No
    Don't know
  }

  answers :frequency, %{
    Never
    Seldom
    Sometimes
    Fairly regularly
    Very regularly
  }

  #-------------------------------------------------------------------------------------
  section 'About You'

  question 'How long have you worked at Red Hat?', %{
    Less than a year
    1-2 years
    3-4 years
    5+ years
  }

  question 'How often do you use Errata Tool?', %{
    Hardly ever
    A few times per year
    At least once a month
    At least once a week
    Every day
  }

  question 'Which answer best describes your role at Red Hat:', %{
    Engineering
    QE
    RCM
    Product Security
    Program Management
    Executive Management
    Content Services
    GSS
  }, :other => true

  text_question 'In what section of Red Hat do you work? (optional)'

  question 'Regarding Errata Tool, do you consider yourself mostly a:', %{
    New user
    Occasional user
    Regular user
    Power user
    Administrator or support provider
  }, :other => true

  text_question 'Describe what you typically do in Errata Tool, (e.g. create advisories, write docs, etc)'

  question 'Are you subscribed to the errata-dev-list mailing list?', :yes_no
  question 'Do you normally join the #errata channel on IRC?', :yes_no
  question 'Do you use any APIs provided by Errata Tool?', :yes_no
  question 'Do you consume any message bus messages published by Errata Tool?', :yes_no

  #-------------------------------------------------------------------------------------
  section 'Overall Satisfaction'

  question 'Your overall experience with Errata Tool is:', %{
    Very bad
    Moderately bad
    Okay
    Moderately good
    Very good
  }

  question 'Compared to 12 months ago your overall experience with Errata Tool is', %{
    Much worse
    A bit worse
    About the same
    A bit better
    Much better
    Did not use 12 months ago
  }

  question "Do you agree or disagree with the following statements:\n" +
    '"I have a good understanding of the Red Hat Errata Process, (i.e. the advisory workflow)."', :agree

  question '"Red Hat Errata (i.e., the advisory workflow) is important to Red Hat and adds value to the company."', :agree

  #-------------------------------------------------------------------------------------
  section "Planning, Development, Support"
  question "Do you agree or disagree with the following statements:\n" +
    '"I am sufficiently informed about planning and upcoming development for Errata Tool"', :agree
  question '"I am happy with the prioritization of development work on Errata Tool"', :agree
  question '"I am happy with the speed at which Errata Tool bug fixes and feature requests are completed"', :agree
  question '"When I have problems with Errata Tool I get the help and support that I need"', :agree

  #-------------------------------------------------------------------------------------
  section 'Documentation'
  question 'How often do you refer to Errata Tool documentation?', :frequency
  question "How useful do you find the documentation for Errata Tool?", :useful
  question 'How often do you read the Errata Tool release notes?', :frequency
  question "Are the release notes useful?", :useful
  question 'Regarding the statement, "Documentation for Errata Tool is easy to find", do you:', :agree

  #-------------------------------------------------------------------------------------
  section 'More details'
  text_question 'Which part of Errata Tool causes you the most pain/difficulty?'
  text_question "Please describe any task you have that you find is particularly difficult " +
    "to perform in ET. Feel free to make suggestions on what you think would make life easier."
  text_question "What else do you think should be improved?"
  text_question "Please add any other feedback you would like to give to the Errata Tool team."
  text_question "Would you be interested in us following up with you to discuss your suggestions "+
    "for Errata Tool improvements? If yes, please add your email address below."

}

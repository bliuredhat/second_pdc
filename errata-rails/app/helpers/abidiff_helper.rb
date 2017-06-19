module AbidiffHelper

  def link_to_abidiff_run(run_id, link_text=nil)
    link_to (link_text || run_id), "#{Settings.abidiff_url}#{run_id}"
  end

end

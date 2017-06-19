module IssuesHelper
  def issue_row(issue_class, issue, issue_type, show_checkbox=false)
    %{<tr class="#{issue_class}">
      #{"<td style='text-align:center'>#{check_box(issue_type, issue.id, :class=>'issue_row_checkbox')}</td>" if show_checkbox}
      <td>#{descriptive_issue_link(issue)}</td>
    </tr>}.html_safe
  end

  def issue_select_all_row
    %{<tr><td colspan="2" style="border-bottom:1px solid #999;">
      #{link_to_function("All",  "issues_select_all(this)",  :title=>"Select all" )},
      #{link_to_function("None", "issues_select_none(this)", :title=>"Select none")}
    </td></tr>}.html_safe
  end
end

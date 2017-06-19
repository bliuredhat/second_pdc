class AutomaticallyFiledAdvisory
  include FormObject
  attr_accessor :errata

  validate :valid_advisory_type, :bugs_available, :packages_selected
  validate :bugs_are_valid, :if => :type_is_valid?

  def initialize(package_ids, params = {})
    @product = Product.find(params[:product][:id])
    @release = Release.find(params[:release][:id])
    @packages = Package.find(package_ids)
    @type = params[:type]
    @security_impact = params[:security_impact] || 'Moderate'
    @bugs = BugsForRelease.new(@release).eligible_bugs.where(:package_id => @packages)
  end

  private

  def bugs_available
    errors.add(:bugs, "No uncovered bugs available") if @bugs.empty?
  end

  def bugs_are_valid
    tmp_errata = Errata.child_get(@type).new(:release => @release,
                                             :product => @product,
                                             :content => Content.new)
    bad = @bugs.collect {|b| FiledBug.new(:bug => b, :errata => tmp_errata)}.reject {|f| f.valid?}
    bad.each {|fb| errors.add(:bugs, fb.errors.full_messages.join(', ') )}
  end

  def type_is_valid?
    Errata.my_child?(@type.constantize)
  end

  def packages_selected
    errors.add(:packages, "No valid packages were selected") if @packages.empty?
  end

  def valid_advisory_type
    return if type_is_valid?
    errors.add(:errata, "Invalid type given for advisory #{@type}")
  end

  def persist!
    Errata.transaction do
      content = Content.new
      @errata = Errata.child_get(@type).new(:release => @release,
                                            :product => @product,
                                            :content => content)

      @errata.synopsis = @packages.first.name + (@errata.is_security? ? " security update" : " bug fix and enhancement update")
      content.topic = "Updated #{@packages.first.name} packages that fix several bugs and add various enhancements are now available."
      content.solution = @product.default_solution.text
      @bugs.each { |b| content.description += "#{b.short_desc}\n\n"}
      @errata.reporter = User.current_user
      @errata.package_owner = @errata.reporter
      @errata.manager = @errata.reporter.organization.manager
      content.keywords = ''
      if content.description.length > 4000
        content.description = "#{@errata.synopsis}\n\nAutomated description using bugs not possible due to length"
      end
      @errata.security_impact = @security_impact if @errata.is_security?
      @errata.set_batch_for_release
      @errata.save!
      content.save!
      bugs_to_use = @bugs.select { |b| FiledBug.new(:bug => b, :errata => errata).valid? }
      FiledBugSet.new(:bugs => bugs_to_use, :errata => errata).save
    end
  end
end

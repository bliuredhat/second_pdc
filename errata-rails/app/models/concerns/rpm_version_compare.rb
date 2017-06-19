module RpmVersionCompare

  def is_newer?(other_rpm)
    compare_versions(other_rpm) == 1
  end

  def is_equal?(other_rpm)
    compare_versions(other_rpm) == 0
  end

  def is_older?(other_rpm)
    compare_versions(other_rpm) == -1
  end

  def compare_versions(other_rpm)
    error_message = "Unable to compare package versions"
    needmethods = [:epoch, :version, :release, :name_nonvr]
    if !needmethods.all?{ |method| other_rpm.respond_to?(method) }
      raise ArgumentError, "#{error_message} because the provided rpm is invalid."
    elsif self.name_nonvr != other_rpm.name_nonvr
      raise ArgumentError, "#{error_message} because packages #{self.name_nonvr} and #{other_rpm.name_nonvr} differ."
    end

    return RpmVersionCompare.rpm_version_compare(self, other_rpm)
  end

  def self.rpm_version_compare(rpm, other_rpm)
    self.rpm_version_compare_evr(
      rpm.epoch, rpm.version, rpm.release,
      other_rpm.epoch, other_rpm.version, other_rpm.release)
  end

  def self.rpm_version_compare_evr(e, v, r, other_e, other_v, other_r)
    if (epoch_cmp = e.to_i <=> other_e.to_i) != 0
      return epoch_cmp
    end
    if (ver_cmp = rpmvercmp(v, other_v)) != 0
      return ver_cmp
    end
    rpmvercmp(r, other_r)
  end

  # Apply special handler for the comparison between 'el' and 'ael' such as
  # 'el' > 'ael' ? -1 : 1
  # See Bug: 1259086#11
  # See also https://engineering.redhat.com/rt/Ticket/Display.html?id=420100
  # Bug: 1378728
  def self.special_cmp(a, b)
    return [a, b].sort == ['ael', 'el'] ? b <=> a : a <=> b
  end

  def self.rpmvercmp(a, b)
    # This function is the equivalent of rpmlib's rpmvercmp() routine.
    # It was translated from rpm 4.6 (or perhaps 4.7.2).  Comments have
    # been preserved where applicable (skipped the ones about manipulating
    # string pointers).  C comment delimiters indicate copied text.

    #### Begin rpmlib rpmvercmp() translation here.....
    # Now compare them by epoch-version-release strings
    isnum = false

    return 0 if (a == b);
    one, two = a.dup, b.dup

    while (one.present? && two.present?)
      one.sub!(/^[^a-zA-Z0-9]+/, '')
      two.sub!(/^[^a-zA-Z0-9]+/, '')

      # /* If we ran to the end of either, we are finished with the loop */
      last if (one.empty? && two.empty?)

      str1, str2 = one.dup, two.dup

      # /* grab first completely alpha or completely numeric segment */
      val1 = ''
      val2 = ''
      if (str1.sub!(/^([0-9]+)/, ''))
        val1 = $1
        if (str2.sub!(/^([0-9]+)/, ''))
          val2 = $1
        end
        isnum = true
      else
        if (str1.sub!(/^([a-zA-Z]+)/, ''))
          val1 = $1
        end
        if (str2.sub!(/^([a-zA-Z]+)/, ''))
          val2 = $1
        end
        isnum = false
      end

      # /* this cannot happen, as we previously tested to make sure that */
      # /* the first string has a non-null segment */
      return(-1) unless (val1.present?)


      # /* take care of the case where the two version segments are */
      # /* different types: one numeric, the other alpha (i.e. empty) */
      # /* numeric segments are always newer than alpha segments */
      # /* XXX See patch #60884 (and details) from bugzilla #50977. */
      return((isnum) ? 1 : -1) unless (val2.present?)

      if isnum
        # /* throw away any leading zeros - it's a number, right? */
        val1.sub!(/^0+/,'')
        val2.sub!(/^0+/, '')

        # /* whichever number has more digits wins */
        return(1)  if (val1.length > val2.length)
        return(-1) if (val2.length > val1.length)
      end

      # /* strcmp will return which one is greater - even if the two */
      # /* segments are alpha or if they are numeric.  don't return  */
      # /* if they are equal because there might be more segments to */
      # /* compare */
      # Seems also to be true of perl's cmp() routine.
      rc = special_cmp(val1, val2)
      return(rc) if rc != 0

      # TESTME: ensure that str1.dup() isn't needed here.
      one = str1
      two = str2
    end

    # /* this catches the case where all numeric and alpha segments have */
    # /* compared identically but the segment sepparating characters were */
    # /* different */
    return(0) if (one.empty? && two.empty?)

    # /* whichever version still has characters left over wins */
    return(-1) if (one.empty?)
    return(1);
  end
  # This concludes the translations from C.

  # This method finds the newest nvr for each package. This doesn't check if the
  # build with nvr actually exists or not. Also it doesn't handle non-nvr format
  # such as id which we already have some handlers for this somewhere else.
  def self.find_newest_nvrs(build_names)
    filtered_build_names = []
    name_vrs = HashSet.new
    build_names.each do |name|
      unless name =~ /^(.*)-([^-]+)-([^-]+)$/
        filtered_build_names << name
        next
      end
      name_vrs[$1] << [$2, $3]
    end
    newest = Hash.new
    name_vrs.each do |name, vrs|
      vrs.each do |vr|
        if !newest[name] ||
           RpmVersionCompare.rpm_version_compare_evr(
             0, vr[0], vr[1],
             0, newest[name][0], newest[name][1]
           ) > 0
          newest[name] = [vr[0], vr[1]]
        end
      end
    end
    newest.each{|name, vr| filtered_build_names << [name,vr].flatten.join('-')}
    filtered_build_names
  end
end

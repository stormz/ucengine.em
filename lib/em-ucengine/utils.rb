class Fixnum
  def days
    return hours * 24
  end

  def hours
    return mins * 60
  end

  def mins
    return self * 60
  end

  def secs
    return self
  end

  alias :day :days
  alias :hour :hours
  alias :min :mins
  alias :sec :secs
end


class Float
  def days
    return hours * 24
  end

  def hours
    return mins * 60
  end

  def mins
    return self * 60
  end

  def secs
    return self
  end

  alias :day :days
  alias :hour :hours
  alias :min :mins
  alias :sec :secs
end

class MyObfuscate
  class ConfigApplicator

    def self.apply_table_config(row, table_config, columns : Array(Symbol))
      return row unless table_config.is_a?(Hash)
      row_hash = row_as_hash(row, columns)

      table_config.each_with_index do |(column, definition), index|
        definition = { :type => definition } if definition.is_a?(Symbol)

        if definition.has_key?(:unless)
          unless_check = make_conditional_method(definition[:unless], index, row)

          next if unless_check.call(row_hash)
        end


        if definition.has_key?(:if)
          if_check = make_conditional_method(definition[:if], index, row)

          next unless if_check.call(row_hash)
        end

        if definition[:skip_regexes]
          skip_regexes = definition[:skip_regexes].as(Array(Regex))
          next if skip_regexes.any? { |regex| row[index] =~ regex }
        end

        row[index] = case definition[:type]
          when :email
            md5 = Crypto::MD5.hex_digest(rand.to_s)[0...5]
            clean_quotes("#{Faker::Internet.email}.#{md5}.example.com")
          when :string
            random_string(definition[:length].as(Int32) || 30, definition[:chars].as(String) || SENSIBLE_CHARS)
          when :lorem
            clean_bad_whitespace(clean_quotes(Faker::Lorem.sentences(definition[:number].as(Int32) || 1).join(".  ")))
          when :like_english
            clean_quotes random_english_sentences(definition[:number].as(Int32) || 1)
          when :name
            clean_quotes(Faker::Name.name)
          when :first_name
            clean_quotes(Faker::Name.first_name)
          when :last_name
            clean_quotes(Faker::Name.last_name)
          when :address
            clean_quotes("#{Faker::Address.street_address}\\n#{Faker::Address.city}, #{Faker::Address.state_abbr} #{Faker::Address.zip_code}")
          when :street_address
            clean_bad_whitespace(clean_quotes(Faker::Address.street_address))
          when :secondary_address
            clean_bad_whitespace(clean_quotes(Faker::Address.secondary_address))
          when :city
            clean_quotes(Faker::Address.city)
          when :state
            clean_quotes Faker::Address.state_abbr
          when :zip_code
            Faker::Address.zip_code
          when :phone
            clean_quotes Faker::PhoneNumber.phone_number
          when :company
            clean_bad_whitespace(clean_quotes(Faker::Company.name))
          when :ipv4
            Faker::Internet.ip_v4_address
          when :ipv6
            Faker::Internet.ip_v6_address
          when :url
            clean_bad_whitespace(Faker::Internet.url)
          when :integer
            random_integer(definition[:between].as(Range(Int32, Int32)) || (0..1000)).to_s
          when :fixed
            if definition[:one_of]
              definition[:one_of].as(Array).sample
            else
              if definition[:string].is_a?(Proc)
                definition[:string].as(Proc).call(row_hash)
              else
                definition[:string]
              end
            end
          when :null
            nil
          when :keep
            row[index]
          else
            STDERR.puts "Keeping a column value by providing an unknown type (#{definition[:type]}) is deprecated.  Use :keep instead."
            row[index]
          end.as(String)
      end
      row
    end

    def self.row_as_hash(row : Array(String | Nil), columns : Array(Symbol))
      columns.zip(row).each_with_object({} of Symbol => (String | Nil))  { |(name, value),m| m[name] = value }
    end

    def self.make_conditional_method(conditional_method, index, row)
      return conditional_method if conditional_method.is_a?(Proc)
      raise "Error" unless conditional_method.is_a?(Symbol)

      if conditional_method == :blank
        Proc(Hash(Symbol, String | Nil), Bool).new { |_| row[index].nil? || row[index].empty? }
      elsif conditional_method == :nil
        Proc(Hash(Symbol, String | Nil), Bool).new { |_| row[index].nil? }
      else
        raise "Error" # TODO Check if this is right
      end
    end

    def self.random_integer(between : Range(Int32, Int32)) : Int32
      (between.min + (between.max - between.min) * rand).round.as(Int32)
    end

    def self.random_string(length_or_range, chars : String)
      range = if length_or_range.is_a?(Int32)
                (length_or_range..length_or_range)
              elsif length_or_range.is_a?(Range)
                length_or_range
              else
                raise "Error"
              end
      times = random_integer(range)
      out = ""
      times.times { out += chars[(rand * chars.size).as(Int32)] }
      out
    end

    def self.walker_method
      @@walker_method ||= begin
                            words, counts = [] of String, [] of Int32
                            File.read(File.expand_path(File.join(File.dirname(__FILE__), "data", "en_50K.txt"))).each_line do |line|
                              word, count = line.split(/\s+/)
                              words << word
                              counts << count.to_i
                            end
                            WalkerMethod.new(words, counts)
                          end
    end

    def self.random_english_sentences(num : Int32)

      sentences = [] of String
      num.times do
        words = [] of String
        (3 + rand * 5).to_i.times { words << walker_method.random }
        sentence = words.join(" ") + "."
        sentences << sentence.capitalize
      end
      sentences.join(" ")
    end

    def self.clean_quotes(value)
      value.gsub(/['"]/, "")
    end

    def self.clean_bad_whitespace(value)
      value.gsub(/[\n\t\r]/, "")
    end

  end
end

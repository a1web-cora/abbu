# lib/abbu/contact.rb
# frozen_string_literal: true

module Abbu
  class Contact
    attr_accessor :first_name, :middle_name, :last_name, :emails,
                  :phones, :company, :addresses, :groups, :group_memberships, :nickname,
                  :prefix, :suffix, :job_title, :department, :maiden_name,
                  :phonetic_first_name, :phonetic_middle_name, :phonetic_last_name,
                  :phonetic_company, :pronouns, :ringtone, :texttone,
                  :urls, :notes, :related_names, :social_profiles,
                  :birthday, :anniversary, :dates, :instant_messages,
                  :verification_code, :lunar_birthday,
                  :image_uri, :image_path,
                  :created_at, :modified_at, :source

    def initialize # rubocop:disable Metrics/MethodLength
      @emails = []
      @phones = []
      @addresses = []
      @groups = []
      @group_memberships = []
      @urls = []
      @notes = []
      @related_names = []
      @social_profiles = []
      @dates = []
      @instant_messages = []
    end

    def full_name
      quoted_nickname = nickname ? "\"#{nickname}\"" : nil
      [prefix, first_name, middle_name, quoted_nickname, last_name, suffix].compact.join(' ')
    end

    def to_s
      "#<Abbu::Contact first_name=#{first_name.inspect} last_name=#{last_name.inspect} " \
        "emails=#{emails.inspect} phones=#{phones.inspect}>"
    end

    def inspect
      to_s
    end
  end
end

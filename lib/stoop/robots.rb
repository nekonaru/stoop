# frozen_string_literal: true

require 'uri'

module Stoop
  # Minimal robots.txt check. Fetches robots.txt for a host once per process
  # and reports whether the given path is disallowed for our user agent.
  # Absent robots.txt (404) means the path is allowed. Anything else
  # (5xx, timeouts, parse errors) means the path is refused, because
  # Stoop honors robots.txt and will not fetch what it cannot check.
  #
  # Implements a conservative subset of RFC 9309: groups are separated by
  # blank lines, the most specific matching user agent group wins, and within
  # a group the longest matching Allow/Disallow prefix decides (Allow wins
  # ties). Only rules in the winning group are applied.
  class Robots
    USER_AGENT = 'Stoop'

    Result = Struct.new(:groups)

    def initialize(http_client: nil, cache: {})
      @http_client = http_client || HttpClient.new
      @cache = cache
    end

    def self.allowed?(url, http_client: nil)
      uri = URI.parse(url)
      new(http_client: http_client).allowed?(uri)
    end

    def allowed?(uri)
      groups = (@cache[uri.host] ||= fetch_groups(uri))
      return true if groups == :missing
      return false if groups.nil?

      group = select_group(groups)
      return true if group.nil?

      path = uri.path.to_s.empty? ? '/' : uri.path.to_s
      best_allow = longest_match(group[:allow], path)
      best_disallow = longest_match(group[:disallow], path)

      return true if best_disallow.nil?
      return false if best_allow.nil?

      best_allow.length >= best_disallow.length
    end

    private

    def fetch_groups(uri)
      robots_uri = robots_uri(uri)
      response = @http_client.get_response(robots_uri)
      return :missing if response.status == 404
      return nil unless response.status.between?(200, 299)

      parse_groups(response.body.to_s)
    rescue StandardError
      nil
    end

    def robots_uri(uri)
      default_port = uri.scheme == 'https' ? 443 : 80
      port_suffix = uri.port && uri.port != default_port ? ":#{uri.port}" : ''
      URI("#{uri.scheme}://#{uri.host}#{port_suffix}/robots.txt")
    end

    # Parses the body into an array of { agents: [...], allow: [...], disallow: [...] } groups.
    def parse_groups(body)
      groups = []
      current = nil

      body.each_line do |raw_line|
        line = raw_line.sub(/#.*\z/, '').strip
        if line.empty?
          current = nil
          next
        end

        key, value = line.split(':', 2).map { |part| part.to_s.strip }
        current = apply_directive(groups, current, key.to_s.downcase, value)
      end

      groups
    end

    def apply_directive(groups, current, key, value)
      case key
      when 'user-agent'
        current = start_group(groups) if current.nil? || current[:allow].any? || current[:disallow].any?
        current[:agents] << value.to_s.downcase
      when 'allow'
        current = start_group(groups) if current.nil?
        current[:allow] << value.to_s unless value.nil? || value.empty?
      when 'disallow'
        current = start_group(groups) if current.nil?
        current[:disallow] << value.to_s unless value.nil?
      end
      current
    end

    def start_group(groups)
      groups << { agents: [], allow: [], disallow: [] }
      groups.last
    end

    # Picks the group whose agent token is the longest match for our user
    # agent. A token matches when it is '*' or a case-insensitive prefix of
    # (or equal to) our token's base name.
    def select_group(groups)
      our = USER_AGENT.downcase
      best = nil
      best_length = -1

      groups.each do |group|
        group[:agents].each do |token|
          next unless token == '*' || our.start_with?(token) || token.start_with?(our)

          length = token == '*' ? 0 : token.length
          if length > best_length
            best = group
            best_length = length
          end
        end
      end

      best
    end

    def longest_match(rules, path)
      rules.select { |rule| !rule.empty? && path.start_with?(rule) }.max_by(&:length)
    end
  end
end

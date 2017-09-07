# frozen_string_literal: true

require 'scraperwiki'
require 'rest-client'
require 'optparse'
require 'pathname'

runners = Pathname.new(__FILE__).parent.join('runners').join('*.rb')
base = Pathname.glob(runners).map(&:to_s).find { |r| r =~ /base_runner/ }
require(base)
Pathname.glob(runners).map(&:to_s).each { |runner| require(runner) }

# Wrapper for all runners
module Jacaranda
  def self.run(args)
    fix_incorrectly_migrated_data!
    parse(args)
    announce
    runners.each(&:run)
  end

  # rubocop:disable Metrics/MethodLength
  def self.fix_incorrectly_migrated_data!
    return if no_tables?

    posts = ScraperWiki.select('* FROM posts')

    # Fix the records
    fixed = posts.each do |r|
      case r['text']
      when /Right To Know/
        r['runner'] = 'RightToKnow::Runner'
      when /PlanningAlerts/
        r['runner'] = 'PlanningAlerts::Runner'
      else
        raise 'wtf'
      end
    end

    # Delete old records
    ScraperWiki.sqliteexecute('DELETE FROM posts')

    # Save
    primary_keys = %w[date_posted runner]
    table_name = 'posts'
    ScraperWiki.save_sqlite(primary_keys, fixed, table_name)
  end
  # rubocop:enable Metrics/MethodLength

  def self.no_tables?
    query = %(SELECT sql FROM sqlite_master where name = 'posts' AND type = 'table')
    ScraperWiki.sqliteexecute(query).empty?
  end

  # rubocop:disable Metrics/MethodLength
  def self.parse(args = [])
    @whitelist = []
    opt_parser = OptionParser.new do |opts|
      opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
      opts.on('-r', '--runners=RUNNER[,<RUNNER>,...]', 'Runners to execute') do |r|
        @whitelist = r.split(',')
      end
      opts.on('-l', '--list-runners', 'List all available runners, then exit') do
        list_runners
        exit(0)
      end
      opts.on('-h', '--help', 'Prints this help') do
        puts opts
        exit
      end
      @whitelist = ENV['MORPH_RUNNERS']&.split(',')
    end
    opt_parser.parse!(args)
  end
  # rubocop:enable Metrics/MethodLength

  def self.runners
    @whitelist ||= []
    candidates = self::BaseRunner.descendants
    unless @whitelist.empty?
      candidates.select! do |c|
        @whitelist.find { |w| c.to_s.split('::').first =~ /#{w}/i }
      end
    end
    candidates.sort_by { |c| c.to_s.split('::').first }.uniq
  end

  def self.announce
    puts 'These are the runners we will execute:'
    puts
    puts runners.map { |r| r.to_s.split('::').first }.join("\n")
    puts
    sleep(2)
  end

  def self.list_runners
    candidates = self::BaseRunner.descendants
    candidates.sort_by { |c| c.to_s.split('::').first }.uniq.each do |runner|
      puts runner.to_s.split('::').first
    end
  end
end

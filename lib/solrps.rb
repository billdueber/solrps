require "solrps/version"
require 'simple_solr_client'


class Solrps
  class Error < StandardError; end

  SCANNER = /-(?:D|XX:)([^\s]+)=([^\s]+)/

  def usage
    puts "Usage: solr_ps_info <username>"
    puts
    puts "If a username isn't given will show all solrs"
  end

  def username_pattern
    if ARGV[0].nil?
      /.*/
    else
      ARGV[0]
    end
  end

  def mbsize(size)
    '%-.2f MB' % size
  end

  def gbsize(size)
    '%-.2f GB' % (size / 1024.0)
  end
  
  def sizestring(size)
    size > 1024 ? gbsize(size) : mbsize(size)
  end
  
  def coredata(client, corename)
    core = client.core(corename)
    {
      core_dir: core.instance_dir,
      data_dir: core.data_dir,
      documents: core.numDocs,
      size_on_disk: sizestring(core.size),
      last_modified: core.last_modified,
    }
  end

  def extracted_ps_data(parts)
    {
      port: parts['jetty.port'],
      jetty_home: parts['jetty.home'],
      solr_home: parts['solr.solr.home'],
      solr_log: solr_log_location(parts),
    }
  end
  

  def solr_supports_api?(client)
    client.major_version >= 6
  end

  def solr_log_location(parts)
    if parts['solr.log.dir']
      parts['solr.log.dir']
    else
      solr_log_maybe = "#{parts['solr.solr.home']}/logs"
      jetty_log_maybe = "#{parts['jetty.home']}/logs"

      if Dir.exist?(solr_log_maybe)
        "(???) #{solr_log_maybe}"        
      elsif Dir.exist?(jetty_log_maybe)
        "(???) #{jetty_log_maybe}"
      else
        "(can't seem to find anything)"
      end
    end
  end
  

  def call
    if ARGV[0] == '-h'
      usage
      exit(0)
    end
    
    `ps aux | grep solr`.split("\n").each do |ps|
      (user, pid) = ps.split(/\s+/).slice(0..1)
      next unless username_pattern.match(user)

      parts = ps.scan(SCANNER).to_h
      next if parts.empty?

      basics = extracted_ps_data(parts)

      puts "#{pid} (owned by #{user})"
      basics.each_pair do |k, v|
        puts '   %-12s  %s' % [k, v]
      end
      
      c = SimpleSolrClient::Client.new(basics[:port].to_i)
      puts '   Cores'
      if solr_supports_api?(c)
        c.cores.each do |corename|
          puts ' ' * 6 +  corename
          coredata(c, corename).each_pair do |k,v|
            puts '        %-15s %s' % [k, v]
          end
        end
      else
        puts " " * 6 + "Core data not available\n      Solr version is #{c.major_version}; requires at least version 6"
      end

      puts "\n\n"

    end

  end

end


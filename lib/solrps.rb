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

  def coredata(client, corename)
    core = client.core(corename)
    size = core.size > 1024 ? "#{core.size / 1024.0}GB" : "#{core.size}MB"
    {
      core_dir: core.instance_dir,
      data_dir: core.data_dir,
      documents: core.numDocs,
      size_on_disk: size,
      last_modified: core.last_modified,
    }
  end

  def extracted_ps_data(parts)
    {
      port: parts['jetty.port'],
      jetty_home: parts['jetty.home'],
      solr_home: parts['solr.solr.home'],
      solr_log: parts['solr.log.dir']
    }
  end
  

  def solr_supports_api?(client)
    client.major_version >= 6
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
            puts '        %-8s %s' % [k, v]
          end
        end
      else
        puts " " * 6 + "Core data not available\n      Solr version is #{c.major_version}; requires at least version 6"
      end

      puts "\n\n"

    end

  end

end


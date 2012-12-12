require 'sinatra'
require 'netaddr'
require 'cgi'

class Array
  def del_in_place(value)
    delete(value)
    self
  end
end

class Bbgist < Sinatra::Base

  SERVER = "http://localhost:4567"
  UPLOAD_DIR = "uploads"
  ID_LENGTH = 10

  # referenced from https://thevault.blueboxgrid.com/index.php/IP_Space_Allocation
  TRUSTED_NETWORKS = ["208.85.144.0/21",
                      "67.214.208.0/20",
                      "199.91.168.0/22",
                      "199.182.120.0/22"]

  USERNAME = "bbgist"
  PASSWORD = "rumor1:newts"

  # before do
  #   authenticate
  # end

  configure do
    enable :sessions
    set :session_secret, "big_secret"
  end

  # show all files
  get '/' do
    if !session["authorized"] && !trusted_ip?
      status, headers, body = call env.merge("PATH_INFO" => '/login')
      [status, headers, body]
    else
      content_type :text
      entries = Dir.entries(path(UPLOAD_DIR)).del_in_place(".").del_in_place("..")
      entries_with_mtime = get_mtimes(entries)
      entries_with_mtime.sort! { |a,b| b.last <=> a.last }
      entries_with_mtime.map { |e| "#{e.first}\t#{e.last.strftime('%Y-%m-%d %H:%M:%S')}" }.join("\n") + "\n"
    end
  end

  # def authenticate
  #   #if !trusted_ip
  #   if true
  #     erb :login
  #   end
  # end

  get '/login' do
    @login_failed = params.key?("login_failed")
    erb :login
  end

  get '/logout' do
    session["authorized"] = false
    redirect '/'
  end

  post '/login' do
    request.body.rewind
    data = CGI.parse(request.body.read)
    username = data["username"].first
    password = data["password"].first

    if username != USERNAME || password != PASSWORD
      redirect '/login?login_failed', 303 # see comment below
      # status, headers, body = call env.merge("PATH_INFO" => '/login')
      # [status, headers, body]
    else
      # start session send them to /
      session["authorized"] = true
      redirect '/', 303 # http://www.gittr.com/index.php/archive/details-of-sinatras-redirect-helper/
    end
  end

  def trusted_ip?
    TRUSTED_NETWORKS.each do |n|
      if NetAddr::CIDR.create(n).contains?(request.ip)
        return true
      end
    end
    false
  end

  def get_mtimes(entries)
    entries.map do |e|
      [ e, File.mtime(path(UPLOAD_DIR, e)) ]
    end
  end

  # show a file
  get '/:name' do |name|
    content_type :text
    return usage if name == "help"
    begin
      File.open(path(UPLOAD_DIR, name), 'r') do |file|
        file.read
      end
    rescue Errno::ENOENT
      "No file #{name}\n"
    end
  end

  # recieve a text upload
  post "/" do

    name = rand_alpha_chars(ID_LENGTH)

    File.open(path(UPLOAD_DIR, name), "w") do |f|
      f.write(params[:file][:tempfile].read)
    end

    return "#{SERVER}/#{name}\n"
  end

  def path(dir, name = nil)
   File.join(File.dirname(__FILE__), dir, name.nil? ? "" : name)
  end

  def rand_alpha_chars(num)
    (0...num).map{  97.+(rand(26)).chr}.join
  end

  def usage
    "curl -F file=@FILE_NAME #{SERVER}\n"
  end

end

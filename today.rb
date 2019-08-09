require 'dotenv'
require 'net/http'
require 'nokogiri'
require 'mechanize'
require 'pp'
require 'time'
require 'uri'

Dotenv.load

postData = {
  'token'   => ENV["SLACK_TOKEN"],
  'channel' => ENV["SLACK_CHANNEL"],
  'text'    => ''
}

if ENV["SLACK_TOKEN"].nil? ||
   ENV["SLACK_CHANNEL"].nil? ||
   ENV["SHOKUDO_EMAIL"].nil? ||
   ENV["SHOKUDO_PASS"].nil? then
  pp 'not found slack token or shokudo id/pass'
  return
end

# LOGIN
url = 'https://minnano.shokudou.jp/users/sign_in'

charset = nil
agent = Mechanize.new
agent.verify_mode = OpenSSL::SSL::VERIFY_NONE

page = agent.get(url)
form = page.form_with(:id => 'new_user')
form['user[email]']    = ENV["SHOKUDO_EMAIL"]
form['user[password]'] = ENV["SHOKUDO_PASS"]
menu_page = agent.submit(form)

doc = Nokogiri::HTML(menu_page.content.toutf8)

# みんなの食堂がおやすみの可能性を考慮
date_section = doc.xpath('//ul[@class="date-list"]/li/section/h2[@class="date__ttl"]/span').first.text.strip
dateArray = /(\d+)\/(\d+)\(/.match(date_section).to_a
menuDate = Date.new(Date.today.year, dateArray[1].to_i, dateArray[2].to_i)
return if menuDate != Date.today

# 献立を取得
main_section = doc.xpath('//ul[@class="date-list"]/li/section/ul[@class="menu-list"]/li').first
main_dish_info = {
	:image => main_section.search('img[@class="menu__img"]').attr('src').value + "?v=#{Time.now.to_i}",
	:name  => main_section.search('h3[@class="menu__ttl"]').text.strip
}

text = "【今日のご飯】 \n#{main_dish_info[:name]}\n#{main_dish_info[:image]}\n\n予約: https://minnano.shokudou.jp/daily_menus"

postData['text'] = text

res = Net::HTTP.post_form(URI.parse('https://slack.com/api/chat.postMessage'), postData)

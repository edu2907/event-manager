require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'yaml'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def validate_phone_number(phone_number)
  phone_number.gsub!(/\D/, '')
  return phone_number if phone_number.length == 10

  return phone_number[1..10] if phone_number.length == 11 && (phone_number[0] == '1')

  'Bad number'
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def get_peak_hour(hours_list)
  hours_list.max_by { |hour| hours_list.count(hour) }
end

def get_often_wday(wday_list)
  wday_list.max_by { |wday| wday_list.count(wday) }
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

phone_list = []
date_list = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_list << validate_phone_number(row[:homephone])
  date_list <<  Time.strptime(row[:regdate], '%Y/%d/%m %H:%M')
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

contents.close

file = File.open('output/data.yaml', 'w+')
data = {
  phone_list:,
  peak_hour: get_peak_hour(date_list.map(&:hour)),
  often_wday: get_often_wday(date_list.map(&:wday))
}
file.puts YAML.dump(data)
file.close

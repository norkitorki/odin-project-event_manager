require 'csv'
require 'erb'
require 'google/apis/civicinfo_v2'
require 'time'

contents = CSV.open(
  '../event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

def date_to_time(date)
  Time.strptime(date, '%m/%d/%Y %H:%M')
end

def peak_registration_hour(time_objects)
  hours = time_objects.map(&:hour)

  hours.uniq.max_by { |hour| hours.count(hour) }
end

def peak_registration_day(time_objects)
  days = time_objects.map { |time| time.strftime('%A') }

  days.uniq.max_by { |day| days.count(day) }
end

def clean_phone_number(phone_number)
  phone_number.delete!('^0-9')

  if phone_number.length == 10
    phone_number
  elsif phone_number.length == 11 && phone_number[0] == '1'
    phone_number[1..]
  else
    ''
  end
end

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zipcode)
  civic_info     = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue
    'You can find your representatives by visiting ' \
      'www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('../output') unless Dir.exist?('../output')

  filename = "../output/thanks_#{id}.html"

  File.open(filename, 'w') { |file| file.puts(form_letter) }
end

puts 'Event Manager Initialized!'

template_letter = File.read('../form_letter.erb')
erb_template    = ERB.new(template_letter)

dates = []

contents.each do |row|
  id           = row[:id]
  name         = row[:first_name]
  phone_number = clean_phone_number(row[:homephone])
  zipcode      = clean_zipcode(row[:zipcode])

  dates[id.to_i - 1] = date_to_time(row[:regdate])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

peak_hour    = peak_registration_hour(dates)
peak_weekday = peak_registration_day(dates)

puts "Most frequent Hour for Registration is #{peak_hour}."
puts "Most frequent Weekday for Registration is #{peak_weekday}."

puts 'Event Manager finished!'

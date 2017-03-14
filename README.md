Duck Record
====

It looks like Active Record and quacks like Active Record, it's Duck Record! 
Actually it's extract from Active Record.

## Usage

```ruby
class Person < DuckRecord::Base
  attribute :name, :string
  attribute :age, :integer

  validates :name, presence: true
end

class Comment < DuckRecord::Base
  attribute :content, :string

  validates :content, presence: true
end

class Book < DuckRecord::Base
  has_one :author, class_name: 'Person', validate: true
  accepts_nested_attributes_for :author

  has_many :comments, validate: true
  accepts_nested_attributes_for :comments

  attribute :title,     :string
  attribute :tags,      :string,   array:   true
  attribute :price,     :decimal,  default: 0
  attribute :meta,      :json,     default: {}
  attribute :bought_at, :datetime, default: -> { Time.new } 

  validates :title, presence: true
end
```

then use these models like a Active Record model,
but remember that can't be persisting!

## Installation
 
Since Duck Record is under early development, 
I suggest you fetch the gem through GitHub. 
 
Add this line to your application's Gemfile:

```ruby
gem 'duck_record', github: 'jasl/duck_record'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install duck_record
```

## TODO

- refactor that original design for database
- update docs
- add useful methods
- add tests 
- let me know..

## Contributing

- Fork the project.
- Make your feature addition or bug fix.
- Add tests for it. This is important so I don't break it in a future version unintentionally.
- Commit, do not mess with Rakefile or version (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
- Send me a pull request. Bonus points for topic branches.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

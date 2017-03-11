Duck Record
====

It looks like Active Record and quacks like Active Record, it's Duck Record! 
Actually it's extract from Active Record.

## Usage

```ruby
class Book < DuckRecord::Base
  attribute :title,     :string
  attribute :price,     :decimal,  default: 0
  attribute :bought_at, :datetime, default: -> { Time.new } 

  # some types that cheated from PG
  attribute :tags,      :string,   array:   true
  attribute :meta,      :json,     default: {}
  
  validates :title, presence: true
end
```

then use `Book` like a Active Record model,
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

- `has_one`, `has_many`
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

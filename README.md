# EasyExport

Export ActiveModels to CSV by declaring headers and fields in your model with the `exportable` class method and block.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'easy_export'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install easy_export

## Usage

In a model, add the `exportable` declaration:

```ruby
class User < ActiveRecord::Base
  exportable do
    scope -> { User.all }
    fields [
      ['Header 1', -> { value to return }],
      ['Header 2', :method_name],
      ['Header 3', 'static value'], ...
    ]
  end
end
```

Now, use the `Exporter` to get the CSV data:

```ruby
exporter = Exportable::Exporter.new params[:export]

exporter.data # The CSV data
exporter.file_type # 'text/csv'
exporter.file_name # 'users-<timestamp>.csv'
```

With those you can initiate a download from a controller: 

```ruby
send_data exporter.data, {
  filetype: exporter.file_type,
  filename: exporter.file_name,
  disposition: 'attachment'
}
```

## Todo

1. Support more export types: XML, JSON, YML
2. Add method to write the data to a file
3. Clean up the way `fields` are declared. 

## Contributing

1. Fork it ( https://github.com/[my-github-username]/easy_export/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

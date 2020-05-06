
# as_history

An ArchivesSpace plugin that adds revision histories for major record types.


Developed by Hudson Molonglo in collaboration with Gaia Resources as part of
the Queensland State Archives Digital Archiving Program project.


## Overview

Whenever a record is created, updated or deleted the event is saved as a version
in the record's revision history. A new `Revision History` button in the left
navigation provides access the list of versions that comprise the record's
history. The features available from this screen include:

  - Summary of the date, time and user of every update to the record since its
    creation
  - Detailed audit metadata for each version of the record
  - A concise view of each version of the record
  - The ability to view the differences between two versions
  - A raw json view of each version or the record
  - Links to other records are rendered as links to versions of those records
    that were current at the time the version being viewed was created
  - The ability to restore a non-current version of a record, even if it has
    been deleted
  - The ability to search the history of the entire system based on criteria
    such as model, id, user and time. For example "All updates to subjects
    by Mary at or before 2020-04-01"

It is also possible to access the History screen via two options in the System
menu:

  - History - All Recent Updates
  - History - My Recent Updates

These two options will show the 20 latest versions created by all users, or the
current user respectively.


## Installation

To install the `as_history` plugin follow this procedure:

  1. Download the latest version of the `as_history` plugin into your
     `archivesspace/plugins/` directory
  2. Add `as_history` to `AppConfig[:plugins]` in `config.rb`
  3. Run `scripts/setup-database.sh` (or `.bat` on windows)

> NOTE: The `as_history` plugin can be installed at any time on an ArchivesSpace
>       instance. It will begin recording version histories from the time it is
>       installed.

> NOTE: There is no special initialization process. The database set up step
>       should complete quickly.


## Configuration

There is no configuration required for `as_history` (beyond adding it to your
plugin list as descibed in the Installation section above.


## Customization

It is possible to customize `as_history` via the `plugin_init.rb` files in
other plugins.

To ensure the customizations are loaded after `as_history` is loaded, add the
following entry to your plugin's `config.yml`:

```yaml
depends_on_plugins:
  - as_history
```

> NOTE: Older versions of ArchivesSpace do not support this config entry. If you
>       are having trouble getting your customizations to work, ensure the
>       `as_history` entry in `AppConfig[:plugins]` comes after your plugin's
>       entry.

If you don't want your plugin to have a strong dependency on `as_history`, but
rather to use it if it is present, but not fail if it isn't, then use this
assertion instead:

```yaml
recommends_plugins:
  - as_history
```

If you do this then be sure to wrap your customizations as follows to avoid
exceptions being thrown at system initialization:

```ruby
begin
  History.register_model(MyModel)
  # ...
rescue NameError
  # This will be thrown if as_history is not installed.
  # We can safely ignore it and move on with our lives.
end
```

The following customizations are supported.


### Model Registration

Defined in `backend/plugin_init.rb`

Example:
```ruby
  History.register_model(MyModel)
```

Register a new model for history (`MyModel` in the example). The model should be
an ASModel class.

By default, all top level models are registered. This facility is only
required if your plugin adds a new model that you want revision histories for.


### Skip Fields

Defined in `frontend/plugin_init.rb`

Example:
```ruby
  HistoryController.add_skip_field('my_boring field')
```

Add a field by name (`my_boring_field` in the example) to be skipped when
rendering the concise view and calculating differences. By default audit fields
and other system level fields are skipped. This facility allows you to skip
other fields that are not relevant to the user view of records.


### Top Fields

Defined in `frontend/plugin_init.rb`

Example:
```ruby
  HistoryController.add_top_fields(['id', 'title', 'display_string'])
```

Force an ordered list of fields to be rendered at the top of the concise record
and difference views (`id`, `title` and `display_string` in the example). By
default the fields will be displayed in the order that they are returned. If a
record doesn't have a field specified in the top fields list then that field
entry will be ignored.


### Enumeration handlers

Defined in `frontend/plugin_init.rb`

Example:
```ruby
  HistoryController.add_enum_handler {|type, field|
    if type == 'date'
      if field == 'certainty_end'
        'date_certainty'
      end
    end
  }
```

Define an enumeration handler for translating enumeration values for display in
the concise record view. The standard ArchivesSpace enumerations should be
translated correctly. If you introduce a new enumeration you may need to add a
handler to ensure its values are translated.

The handler will be passed a record type (`type`) and field name (`field`). Your
handler should use these parameters to determine the correct name of your
enumeration and return it. In the example if the renderer finds a field called
`certainty_end` on a `date` record then this handler will cause it to look up
its translation in an enumeration called `date_certainty`.

You can add as many enumeration handlers as you like. The renderer will go
through them in the order they are specified and will use the first one that
returns a value.


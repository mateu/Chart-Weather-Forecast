package Chart::Weather::Types;
use Moose::Util::TypeConstraints;

# type definition.
subtype 'State', 
  as 'Str', 
  where { length $_ == 2 },
  message { "State is not two characters long" };

coerce 'State',
    from 'Str',
    via {uc $_};

subtype 'City', 
  as 'Str', 
  where { length $_ > 0 },
  message { "City is empty" };

coerce 'City',
    from 'Str',
    via {ucfirst lc $_};
    
1
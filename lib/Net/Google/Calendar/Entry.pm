package Net::Google::Calendar::Entry;

use strict;
use Data::Dumper;
use DateTime;
use XML::Atom;
use XML::Atom::Entry;
use XML::Atom::Util qw( set_ns first nodelist childlist iso2dt);
use base qw(XML::Atom::Entry Net::Google::Calendar::Base);



=head1 NAME

Net::Google::Calendar::Entry - entry class for Net::Google::Calendar

=head1 SYNOPSIS

    my $event = Net::Google::Calendar::Entry->new();
    $event->title('Party!');
    $event->content('P-A-R-T-Why? Because we GOTTA!');
    $event->location("My Flat, London, England");
    $event->status('confirmed'); 
    $event->transparency('opaque');
    $event->visibility('private'); 

    my $author = Net::Google::Calendar::Person->new;
    $author->name('Foo Bar');
    $author->email('foo@bar.com');
    $entry->author($author);



=head1 DESCRIPTION

=head1 METHODS

=head2 new 

Create a new Event object

=cut

sub new {
    my ($class, %opts) = @_;

    my $self  = $class->SUPER::new( Version => '1.0', %opts );
    $self->_initialize();
    return $self;
}

sub _initialize {
    my $self = shift;                                                                               
                                                                                                  
    $self->category({ scheme => 'http://schemas.google.com/g/2005#kind', term => 'http://schemas.google.com/g/2005#event' } );
                                                                                                  
    $self->{_gd_ns} = XML::Atom::Namespace->new(gd => 'http://schemas.google.com/g/2005');          
}

=head2 id [id]

Get or set the id.

=cut

=head2 title [title]

Get or set the title.

=cut

=head2 content [content]

Get or set the content.

=cut

sub content {
    my $self= shift;
    if (@_) {
        $self->set($self->ns, 'content', shift);  
    }
    return $self->SUPER::content;
}

=head2 author [author]

Get or set the author

=cut

=head2 transparency [transparency] 

Get or set the transparency. Transparency should be one of

    opaque
    transparent

=cut

sub transparency {
    my $self = shift;
    return $self->_gd_element('transparency', @_);
}


=head2 visibility [visibility] 

Get or set the visibility. Visibility should be one of

    confidential
    default
    private
    public 

=cut

sub visibility {
    my $self = shift;
    return $self->_gd_element('visibility', @_);
}

=head2 status [status]

Get or set the status. Status should be one of

    canceled
    confirmed
    tentative

=cut

sub status {
    my $self = shift;
    return $self->_gd_element('eventStatus', @_);    
}

sub _gd_element{
    my $self = shift;
    my $elem = shift;

    if (@_) {
        my $val = lc(shift);
        $self->set($self->{_gd_ns}, "gd:${elem}",  '', { value => "http://schemas.google.com/g/2005#event.${val}" });
        return $val;
    }
    my $val = $self->_attribute_get($self->{_gd_ns}, $elem, 'value');
    $val =~ s!^http://schemas.google.com/g/2005#event\.!!;
    return $val;
}

sub _attribute_get {
    my ($self, $ns, $what, $key) = @_;
    my $elemt = $self->_my_get($self->{_gd_ns}, $what, $key);
    
     if ($elem->hasAttribute($key)) {
            return $elem->getAttribute($key);
        } else {
            return $elem;
        }
    }

}

=head2 location [location]

Get or set the location

=cut

sub location {
    my $self = shift;

    if (@_) {
        my $val = shift;
        $self->set($self->{_gd_ns}, 'where', '', { valueString => $val});
        return $val;
    }
    
    return $self->_attribute_get($self->{_gd_ns}, 'where', 'valueString');
}


=head2 when [<start> <end> [allday]]

Get or set the start and end time as supplied as DateTime objects. 
End must be more than start.

You may optionally pass a paramter in designating if this is an all day event or not.

Returns two DateTime objects depicting the start and end. 


=cut

sub when {
    my $self = shift;

    if (@_) {
        my ($start, $end, $allday) = @_;
        $allday = 0 unless defined $allday;
        unless ($end>$start) {
            $@ = "End is not less than start";
            return undef;
        }
        $start->set_time_zone('UTC');
        $end->set_time_zone('UTC');
        
        my $format = $allday ? "%F" : "%FT%TZ";

        $self->set($self->{_gd_ns}, "gd:when",  '', { 
            startTime => $start->strftime($format),
            endTime   => $end->strftime($format),
        });        
    }
    my $start = $self->_attribute_get($self->{_gd_ns}, 'when', 'startTime');
    my $end   = $self->_attribute_get($self->{_gd_ns}, 'when', 'endTime');
    my @rets;
    if (defined $start) {
        push @rets, $start;
    } else {
        return @rets;
        #die "No start date ".$self->as_xml;
    }
    if (defined $end) {
        push @rets, $end;
    } 
    return map { iso2dt($_) } @rets;

}



=head2 who [Net::Google::Calendar::Person[s]]

Get or set the list of event invitees.

If no parameters are passed then it returns a list containing zero 
or more Net::Google::Calendar::Person objects.

If you pass in one or more Net::Google::Calendar::Person objects then 
they get set as the invitees.

=cut

# TODO this needs a lot of work
# for example attendeeType, attendeeStatus and entryLink
# http://code.google.com/apis/gdata/elements.html#gdWho
sub who {
    my $self = shift;

    my $ns_uri = $self->{_gd_ns};
    my $name   = 'who';
    if (@_) {
        my @elem = $self->_my_getlist($ns_uri, $name);
           $self->elem->removeChild($_) for @elem;
        for my $person (@_) {
            my $stuff = { rel => "http://schemas.google.com/g/2005#event.attendee" };
            $stuff->{email}       = $person->email if $person->email;
            $stuff->{valueString} = $person->name  if $person->name;
            $self->add($ns_uri,"gd:${name}", '', $stuff);
        }     
    }
    my @who = map {
       my $person = Net::Google::Calendar::Person->new();
       $person->email($_->getAttribute("email")) if defined $_->getAttribute("email");
       $person->name($_->getAttribute("valueString")) if defined $_->getAttribute("valueString");
       $person;
    } $self->_my_getlist($ns_uri,$name);
}




=head2 edit_url 

Return the edit url of this event.

=cut


sub edit_url {
    return $_[0]->_generic_url('edit');
}


=head2 self_url

Return the self url of this event.

=cut



sub self_url {
    return $_[0]->_generic_url('self');
}

sub _generic_url {
    my $self = shift;
    my $name = shift;
    my $uri;
    for ($self->link) {
        next unless $name eq $_->rel;
        $uri = $_;
        last;
    }
    return undef unless defined $uri;
    return $uri->href;
}




=head2 recurrence [ Data::ICal::Entry::Event ]

Get or set a recurrence for an entry - this is in the form of a Data::ICal::Entry::Event object. 

Returns undef if there's no recurrence event

This will not work if C<Data::ICal> is not installed and will return undef.

For example ...

    $event->title('Pay Day');
    $event->start(DateTime->now);

    my $recurrence = Data::ICal::Entry::Event->new();


    my $last_day_of_the_month = DateTime::Event::Recurrence->monthly( days => -1 );
    $recurrence->add_properties(
               dtstart   => DateTime::Format::ICal->format_datetime(DateTime->now),
               rrule     => DateTime::Format::ICal->format_recurrence($last_day_of_the_month),
    );

    $entry->recurrence($recurrence);

To get the recurrence back:

    print $entry->recurrence->a_string;

See 

    http://code.google.com/apis/gdata/common-elements.html#gdRecurrence

For more details

=cut

sub recurrence {
    my $self = shift;
    
    # we need Data::ICal for this but we don't wnat to require it
    eval {
        require Data::ICal;
        Data::ICal->import;
        require Data::ICal::Entry::Event;
        Data::ICal::Entry::Event->import;
    
    };
    if ($@) {
        $@ = "Couldn't load Data::ICal or Data::ICal::Entry::Event: $@";
        return;
    }

    # this is all one massive hack. 
    # I hate myself for writing this.
    if (@_) {
        my $event  = shift;
        # pesky Google Calendar needs you to remove the BEGIN:VEVENT END:VEVENT. TSSSK
        my $recur =  $event->as_string;

        $recur =~ s!(^BEGIN:VEVENT\n|END:VEVENT\n$)!!sg; 
        $self->set($self->{_gd_ns}, 'gd:recurrence', $recur);

        return $event;
    }
    my $string = $self->get($self->{_gd_ns}, 'recurrence');
    return undef unless defined $string;
    $string =~ s!\n+$!!g;
    $string = "BEGIN:VEVENT\n${string}\nEND:VEVENT";
    print "Recurrence is $string\n";
    my $vfile = Text::vFile::asData->new->parse_lines( split(/\n/, $string) );
    my $event = Data::ICal::Entry::Event->new();
    #return $event;

    $event->parse_object($vfile->{objects}->[0]);
    return $event->entries->[0];

}


=head1 TODO

=over 4

=item more complex content

=item more complex locations

=item recurrency

=item comments

=back

See http://code.google.com/apis/gdata/common-elements.html for details

=head1 AUTHOR

Simon Wistow <simon@thegestalt.org>

=head1 COPYRIGHT

Copyright Simon Wistow, 2006

Distributed under the same terms as Perl itself.

=head1 SEE ALSO

http://code.google.com/apis/gdata/common-elements.html

L<Net::Google::Calendar>

L<XML::Atom::Event>

=cut



1;

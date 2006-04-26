package Net::Google::Calendar::Entry;

use strict;
use Data::Dumper;
use DateTime;
use XML::Atom;
use XML::Atom::Entry;
use XML::Atom::Util qw( set_ns first nodelist iso2dt);
use base qw(XML::Atom::Entry);


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
    $self->category('', { scheme => 'http://schemas.google.com/g/2005#kind', term => 'http://schemas.google.com/g/2005#event' } );

    $self->{_gd_ns} = XML::Atom::Namespace->new(gd => 'http://schemas.google.com/g/2005');
    return $self;
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
    my $val = $self->_my_get($self->{_gd_ns}, $elem, 'value');
    $val =~ s!^http://schemas.google.com/g/2005#event\.!!;
    return $val;
}

=head2 location [location]

Get or set the location

=cut

sub location {
    my $self = shift;

    if (@_) {
        my $val = shift;
        $self->set($self->{_gd_ns}, 'gd:where', '', { valueString => $val});
        return $val;
    }
    
    return $self->_my_get($self->{_gd_ns}, 'where', 'valueString');
}

# work round get in XML::Atom::Thing
sub _my_get {
   my $atom = shift;
   my($ns, $name, $attr) = @_;
   my $ns_uri = ref($ns) eq 'XML::Atom::Namespace' ? $ns->{uri} : $ns;
   my $node = first($atom->{doc}, $ns_uri, $name);
   return $node unless defined $node && defined $attr;
   my $val;
   if ($attr eq 'content') {
      $val = LIBXML ? $node->textContent : $node->string_value;
   } else {
      # both LibXML and XPath element nodes have the same syntax
      $val = $node->getAttribute($attr); 
   }
   if ($] >= 5.008) {
        require Encode;
        Encode::_utf8_off($val);
   }
   $val;

}

=head2 when [<start> <end>]

Get or set the start and end time as supplied as DateTime objects. 
End must be more than start.

Returns two DateTime objects depicting the start and end. 


=cut

sub when {
    my $self = shift;

    if (@_) {
        my ($start, $end) = @_;
        unless ($end>$start) {
            $@ = "End is not less than start";
            return undef;
        }
        $self->set($self->{_gd_ns}, "gd:when",  '', { 
            startTime => $start->iso8601 . 'Z',
            endTime   => $end->iso8601 . 'Z',
        });        
    }
    my $start = $self->_my_get($self->{_gd_ns}, 'when', 'startTime');
    my $end   = $self->_my_get($self->{_gd_ns}, 'when', 'endTime');
    return (iso2dt($start), iso2dt($end));

}

=head2 edit_url 

Return the edit url of this event.

=cut

sub edit_url {
    my $self = shift;
    my $edit;
    for ($self->link) {
        next unless 'edit' eq $_->rel;
        $edit = $_;
        last;
    }
    return undef unless defined $edit;
    return $edit->href;
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

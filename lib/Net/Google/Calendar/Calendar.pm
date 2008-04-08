package Net::Google::Calendar::Calendar;

use base qw(Net::Google::Calendar::Entry);

=head1 NAME

Net::Google::Calendar::Calendar - entry class for Net::Google::Calendar Calendar objects

=head1 METHODS 

Note this is very rough at the moment - there are plenty of
convenience methods that could be added but for now you'll
have to access them using the underlying C<XML::Atom::Entry>
object.

=head2 new 

=cut

sub new {
    my ($class, %opts) = @_;

    my $self  = $class->SUPER::new( Version => '1.0', %opts );
    $self->_initialize();
    return $self;
}

sub _initialize {
    my $self = shift;

    $self->{_gd_ns}   = XML::Atom::Namespace->new(gd => 'http://schemas.google.com/g/2005');
    $self->{_gcal_ns} = XML::Atom::Namespace->new(gCal => 'http://schemas.google.com/gCal/2005');
}

=head2 summary [value]

A summary of the calendar.

=cut 

sub summary {
    my $self= shift;
    if (@_) {
        $self->set($self->ns, 'summary', shift);
    }
    return $self->get($self->ns, 'summary');
}


=head2 edit_url

Get the edit url

=cut

sub edit_url {
    my $self  = shift;
    my $force = shift || 0;
    my $url   = $self->_generic_url('edit');

    $url      =~ s!/allcalendars/full!/owncalendars/full! if $force;
    return $url;
}
1;

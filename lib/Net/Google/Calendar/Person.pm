package Net::Google::Calendar::Person;

use strict;
use XML::Atom::Person;
use base qw(XML::Atom::Person);

=head1 NAME

Net::Google::Calendar::Person - a thin wrapper round XML::Atom::Person

=cut

sub new {
	my $class = shift;
	my %opts  = @_; 
	$opts{Version} = '1.0' unless exists $opts{Version};
	return $class->SUPER::new(%opts);
}

1;

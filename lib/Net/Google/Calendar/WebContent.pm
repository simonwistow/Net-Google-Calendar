package Net::Google::Calendar::WebContent;

use strict;
use XML::Atom::Link;
#use XML::Atom::Namespace;
use base qw(XML::Atom::Link Net::Google::Calendar::Base);
use vars qw(@ISA);
unshift @ISA, 'XML::Atom::Link';
my $ns = XML::Atom::Namespace->new(
    gCal => 'http://schemas.google.com/gCal/2005'
);

sub new {
    my $class  = shift;
    my %params = @_;
    
    #my $self   =  XML::Atom::Link->new(Version => "1.0");
    #$self = bless $self, $class;
    my $self = $class->SUPER::new(Version => "1.0");
    $self->rel('http://schemas.google.com/gCal/2005/webContent');
    for my $field (qw(title href)) {
		die "You must pass in the field '$field' to a WebContent link\n" 
            unless defined $params{$field};
        $self->$field($params{$field}); 
    }
    my $type = $params{type};
    $self->_set_type($type) if defined $type;

    if ($params{webContent}) {
        $self->webContent(%{$params{webContent}}); 
    } else {
        # h-h-hack
        $self->webContent(empty => 1);
    }
    return $self;
}

sub _set_type {
     my $self = shift;
     my $type = shift;
     unless ($type eq 'text/html' or $type =~ m!^image/!) {
         die "The type param must be text/html or image/*\n";
     }
     $self->type($type);

}

sub webContent {
	my $self = shift;
    if (@_) {
        my %params = @_;
        # h-h-hack
        %params    = () if $params{emtpy};
        if (my $type = delete $params{type}) {
            $self->_set_type($type);
        }  
        XML::Atom::Thing::set($self, $ns, 'webContent', '', \%params);
    }
    return $self->_my_get($ns, 'webContent');
}

1;



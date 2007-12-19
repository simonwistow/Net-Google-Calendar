package Net::Google::Calendar::WebContent;

use strict;
use XML::Atom;
use XML::Atom::Link;
#use XML::LibXML;
#use XML::Atom::Namespace;
use base qw(XML::Atom::Link Net::Google::Calendar::Base);
use vars qw(@ISA);
unshift @ISA, 'XML::Atom::Link';
my $ns = XML::Atom::Namespace->new(
    gCal => 'http://schemas.google.com/gCal/2005'
);


=head1 NAME

Net::Google::Calendar::WebContent - handle web content

=head1 SYNOPSIS

Web content can be images ...

    my $content = Net::Google::Calendar::WebContent->new(
        title      => 'World Cup',
        href       => 'http://www.google.com/calendar/images/google-holiday.gif',
        webContent => {
            url    => "http://www.google.com/logos/worldcup06.gif" 
            width  => 276,
            height => 120,
            type   => 'image/gif',
        }
    );
    $entry->add_link($content);

or html ...

    my $content = Net::Google::Calendar::WebContent->new(
        title      => 'Embedded HTML',
        href       => 'http://www.example.com/favico.icon',
        webContent => {
            url    => "http://www.example.com/some.html" 
            width  => 276,
            height => 120,
            type   => 'text/html',
        }
    );
    $entry->add_link($content);


or special Google Gadgets (http://www.google.com/ig/directory)

    my $content = Net::Google::Calendar::WebContent->new(
        title      => 'DateTime Gadget (a classic!)',
        href       => 'http://www.google.com/favicon.ico',
        webContent => {
            url    => 'http://google.com/ig/modules/datetime.xml',
            width  => 300,
            height => 136,
            type   => 'application/x-google-gadgets+xml',
        }
    );


or
    my $content = Net::Google::Calendar::WebContent->new(
        title      => 'Word of the Day',
        href       => 'http://www.thefreedictionary.com/favicon.ico',
    );
    $content->webContent(
            url    => 'http://www.thefreedictionary.com/_/WoD/wod-module.xml',
            width  => 300,
            height => 136,
            type   => 'application/x-google-gadgets+xml',
            prefs  => { Days => 1, Format => 0 },
    );

(note the ability to set webContentGadgetPrefs using the special prefs attribute).

=cut

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
    #die "You must pass a type" unless defined $type;
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
     unless ($type eq 'text/html' or 
             $type eq 'application/x-google-gadgets+xml' or
             $type =~ m!^image/!) {
         die "The type param must be text/html or application/x-google-gadgets+xml or image/*\n";
     }
     $self->type($type);

}

sub webContent {
    my $self = shift;
    my $name    = 'gcal:webContent';
    if (@_) {
        my %params = @_;
        # h-h-hack
        %params    = () if $params{empty};
        if (my $type = delete $params{type}) {
            $self->_set_type($type);
        }  
         my $prefs   = delete $params{prefs};    
        XML::Atom::Base::set($self, '', $name, '', \%params);
        my $content = $self->_my_get('', $name); 
        foreach my $key (keys %{$prefs}) {
            # TODO: this feels icky
            my $node;
            if (LIBXML) {
                $node = XML::LibXML::Element->new($name.'GadgetPref');
                $node->setAttribute( Name  => $key );
                $node->setAttribute( Value => $prefs->{$key} );
            } else {
                $node = XML::XPath::Node::Element->new($name.'GadgetPref');
                $node->addAttribute(XML::XPath::Node::Attribute->new(Name  => $key));
                $node->addAttribute(XML::XPath::Node::Attribute->new(Value => $prefs->{key}));
            }
            $content->appendChild($node);
        }
    }
    return $self->_my_get('', $name);
}

1;



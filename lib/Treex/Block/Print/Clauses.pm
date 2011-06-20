package Treex::Block::Print::Clauses;
use Moose;
use Treex::Core::Common;
use Treex::Core::TredView::Colors;
use Tk;
use Tk::Button;

extends 'Treex::Core::Block';
with 'Treex::Block::Write::Redirectable';

sub build_language { return log_fatal "Parameter 'language' must be given"; }
has 'source_selector' => ( is => 'rw', isa => 'Str', default => 'test' );

has '_colors' => (
    is => 'ro',
    isa => 'Treex::Core::TredView::Colors',
    default => sub { Treex::Core::TredView::Colors->new() }
);

has _colorizer => (
    is => 'ro',
    isa => 'Tk::Button',
    default => sub { Tk::Button->new(tkinit()) }
);

sub BUILD {
    my $self = shift;  
    my @colors = map { $self->_colors->get_clause_color($_) } (0 .. 9);
    print {$self->_file_handle} '<html><head>',
        '<meta content="text/html; charset=utf-8" http-equiv="Content-Type">',
        '<style type="text/css">'
    ;
    foreach my $i ( 0 .. $#colors) {
        my $hex = $self->_name2hex($colors[$i]);
        print {$self->_file_handle} ".clause$i { color: $hex; }";
    }
    print {$self->_file_handle} '</style></head>';
}

sub _name2hex {
    my ($self, $clr) = @_;
    my ($r, $g, $b) = $self->_colorizer->rgb($clr);
    my ($max, undef, undef) = $self->_colorizer->rgb('white');
    $r /= $max; $g /= $max; $b /= $max;
    $r *= 255; $g *= 255; $b *= 255;
    return sprintf '#%02x%02x%02x', int($r), int($g), int($b);
}

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $gold_zone = $bundle->get_zone( $self->language, $self->selector );
    my $gold_root = $gold_zone->get_atree;
    
    my $test_zone = $bundle->get_zone( $self->language, $self->source_selector );
    my $test_root = $test_zone->get_atree;
    
    print {$self->_file_handle}
      '<p>',
      $self->_get_sentence_html($test_root),
      $self->_get_sentence_html($gold_root),
      '</p>'
    ;
}

sub _get_sentence_html {
    my ($self, $aroot) = @_;  
    my @anodes = $aroot->get_descendants( { ordered => 1 } );
    my @out;
    for my $anode (@anodes) {
        if( $anode->clause_number ) {
            push @out,
              '<span class="clause' .
              $anode->clause_number .
              '">' . 
              $anode->form .
              '</span>'
        }
        else {
            push @out, $anode->form;
        }
        if ( !$anode->no_space_after ) {
            push @out, ' ';
        }
    }
    push @out, '</br>';
    return join '', @out;

}

sub DEMOLISH {
    my $self = shift;  
    print {$self->_file_handle} '</body></html>';
}

1;

=head1 NAME

Treex::Block::Print::Clauses

=head1 DESCRIPTION

Prints HTML formatted sentences segmented to clauses.

=cut

# Copyright 2011 Jan Popelka
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

package Treex::Tool::Parser::MSTperl::Writer;

use Moose;
use autodie;

has featuresControl => (
    isa      => 'Treex::Tool::Parser::MSTperl::FeaturesControl',
    is       => 'ro',
    required => '1',
);

sub write_tsv {

    # (Str $filename, ArrayRef[Treex::Tool::Parser::MSTperl::Sentence] $sentences)
    my ( $self, $filename, $sentences ) = @_;

    open my $file, '>:utf8', $filename;
    foreach my $sentence ( @{$sentences} ) {
        foreach my $node ( @{ $sentence->nodes } ) {

            #($ord, $form, $lemma, $pos, $subpos, $features, $parent, $afun, $underscore1, $underscore2)
            my @line = @{ $node->fields };
            $line[ $self->featuresControl->parent_ord_field_index ] = $node->parentOrd;
            print $file join "\t", @line;
            print $file "\n";
        }
        print $file "\n";
    }
    close $file;
}

1;

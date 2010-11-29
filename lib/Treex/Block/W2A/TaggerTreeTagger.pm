package Treex::Block::W2A::TaggerTreeTagger;

our $VERSION = '0.1';

use Moose;
use MooseX::FollowPBP;

use Report;

extends 'Treex::Core::Block';

has 'language' => (isa => 'Str', is => 'ro', required => 1);
has 'model'    => (isa => 'Str', is => 'rw');

use Treex::Tools::Tagger::TreeTagger;

sub BUILD {
    my ($self) = @_;

    # check whether there is a default model for given language
    if (!$self->{model}) {
        my $possible_model = "$ENV{TMT_ROOT}/share/data/models/tree_tagger/".$self->{language}.".par";
        if (-e $possible_model) {
            $self->{model} = $possible_model;
        }
        else {
            Report::fatal("Model filename has not been specified and the default model $possible_model has not been found.");
        }
    }

    $self->{tagger} = Treex::Tools::Tagger::TreeTagger->new({'model' => $self->{model}});
    return;
}

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $a_root = $bundle->get_tree('S'.$self->{language}.'A');
    my @forms = map { $_->get_attr('m/form') } $a_root->get_descendants();
    my ($tags, $lemmas) = @{ $self->{tagger}->analyze(\@forms) };

    # fill tags and lemmas
    foreach my $a_node ( $a_root->get_descendants() ) {
        $a_node->set_attr( 'm/tag',   shift @$tags );
        $a_node->set_attr( 'm/lemma', shift @$lemmas );
    }

    return 1;
}

1;


__END__

=pod

=over

=item Treex::Block::W2A::TaggerTreeTageer

=back

=cut

# Copyright 2010 David Marecek
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

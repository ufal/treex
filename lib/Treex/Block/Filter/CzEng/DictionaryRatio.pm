package Treex::Block::Filter::CzEng::DictionaryRatio;
use Moose;
use Treex::Core::Common;
use Treex::Tool::TranslationModel::Static::Universal;
use Treex::Block::Filter::CzEng::Common;

extends 'Treex::Block::Filter::CzEng::Common';

has model_file => (
    isa           => 'Str',
    is            => 'rw',
    required      => 0,
    default       => "resource_data/translation_dictionaries/czeng_prob_dict.tsv",
);

has _dictionary => (
    is            => 'rw',
    required      => '0',
);

sub BUILD {
    my $self = shift;
    my $dictfile = Treex::Core::Resource::require_file_from_share($self->{model_file});
    $self->{_dictionary} = Treex::Tool::TranslationModel::Static::Universal->new(
      {
        file=>$dictfile,
        columns=>['main_key', 'value', 'prob'],
      }
    );
}

sub tag2simplepos {
    my ($tag, $tagset) = @_;
    if (not defined $tag or $tag eq "") {
        Report::fatal('Undefined or empty tag');
    }
    if (not defined $tagset or $tagset eq "") {
        Report::fatal('Undefined or empty tagset');
    }

    my $simplepos;

    if ($tagset eq 'pdt') {
        if ($tag =~ /^([NAVD])/) {
            $simplepos = $1;
        }
        else {
            $simplepos = 'X';
        }
    }

    elsif ($tagset eq 'ptb') {
        if ($tag =~ /^([NV])/) {
            $simplepos = $1;
        }
        elsif ($tag =~ /^J/) {
            $simplepos = 'A';
        }
        elsif ($tag =~ /^R/) {
            $simplepos = 'D';
        }
        else {
            $simplepos = 'X';
        }
    }

    else {
        Report::fatal("Unsupported tagset: $tagset");
    }

    return $simplepos;
}

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my @en = $bundle->get_zone('en')->get_atree->get_descendants;
    my @cs = $bundle->get_zone('cs')->get_atree->get_descendants;

    my %cs_lemmas = map {
        my $lemma = $_->get_attr("lemma");    # get lemma
        $lemma =~ s/[_-].*$//;                # only keep the base form
        lc($lemma) => 1;
    } @cs;

    my $covered = 0;                          # number of English words covered in Czech

    my $has_translation = 0;

    for my $en_node (@en) {
        my $en_lemma      = lc( $en_node->get_attr("lemma") );
        my $en_tag_simple = tag2simplepos( $en_node->get_attr("tag"), "ptb" );
        my @trans         = $self->{_dictionary}->translations_of( "$en_lemma#$en_tag_simple" );
        if ( @trans ) {
            $has_translation++;
            $covered++ if grep { $cs_lemmas{$_} } map { ($_) = split '#', lc($_) } @trans;
            # log_info $en_lemma . ": " . join( " ", map { ($_) = split '#', lc($_) } @trans );
        }
    }

    my $reliable = $has_translation >= 5 ? "reliable_" : "rough_";
    my @bounds = ( 0, 0.2, 0.5, 0.8, 1 );

    if ( $has_translation ) {
        $self->add_feature( $bundle, $reliable . "dictratio="
            . $self->quantize_given_bounds( $covered / $has_translation, @bounds ) );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::DictionaryRatio

=back

A filtering feature. Computes the ratio of English words whose
translations appear in the Czech side based on translation dictionary.
Check is case insensitive.

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

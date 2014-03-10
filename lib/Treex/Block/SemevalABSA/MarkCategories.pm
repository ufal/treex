package Treex::Block::SemevalABSA::MarkCategories;
use WordNet::QueryData;
use List::MoreUtils qw/ uniq /;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
extends 'Treex::Block::SemevalABSA::BaseRule';

has wn_instance => (
    isa => 'Any',
    is => 'rw',
);

has wn_path => (
    isa => 'String',
    default => '/data/resources/wordnet3.0/new/WordNet-3.0/dict/',
    is => 'ro',
);

my %exceptions = (
  people => "service",
  portions => "food",
  taste => "food",
  romantic => "ambience",
  value => "price",
  music => "ambience",
  bill => "price",
  delivery => "service", 
  variety => "food",
  noise => "ambience",
  bottle => "food",
  second => "food",
  stuff => "food",
  cost => "price",
  stomach => "food",
);

my %known = (
  chemical => "food",
  cost => "price",
  atmosphere => "ambience",
  environment => "ambience",
  area => "ambience",
  place => "ambience",
  job => "service",
  music => "ambience",
  habitant => "food",
  location => "ambience",
  worker => "service",
  serving => "food",
  cooking => "food",
  consumption => "food",
  bill => "price",
  organization => "service",
  individual => "service",
);

sub BUILD {
    my ( $self ) = @_;
    my $wn_realpath = Treex::Core::Resource::require_file_from_share( $self->wn_path );
    $self->{wn_instance} = WordNet::QueryData->new( $wn_realpath );

    return 1;
}

sub _get_all_hyperonyms {
    my ( $self, $node ) = @_;
    return if $node->tag !~ m/^N/; # only handle nouns
    my @queue = $self->wn->querySense( $node->lemma . "#n" );
    my %hyperonyms;
    while ( shift @queue ) {
        my $current = $_;
        $hyperonyms{ $current } = 1;
        my @hyper = grep { ! $hyperonyms{ $_ } && ! m/^entity/ }
            $self->wn->querySense( $hyper, "hype" );
        push @queue, @hyper;
    }

    map { $_ =~ s/#.*// } keys %hyperonyms;
    return keys %hyperonyms;
}

sub process_atree {
    my ( $self, $atree ) = @_;
    my %polarities;
    for my $node ( grep { $self->is_aspect_candidate( $_ ) } $atree->get_descendants ) {
        my $polarity = $self->get_candidate_polarity( $_ );
        if ( $exceptions{ $node->lemma } ) {
            push @{ $polarities{ $exceptions{ $node->lemma } } }, $polarity;
        } else {
            my @hypers = grep { $known{ $_ } } $self->_get_all_hyperonyms( $node );
            if ( @hypers ) {
                # let's just take the first known hyperonym
                push @{ $polarities{ $known{ $hyper[0] } } }, $polarity;
            }
        }
    }

    if ( %polarities ) {
        my $categorystr = "#CAT#";

        for my $category ( keys %polarities ) {
            my $polarity = $self->combine_polarities( $polarities{ $category } );
            $categorystr .= " $category$polarity";
        }

        # let's just rudely prepend our annotation to the first word
        my ( $first ) = $atree->get_descendants( { ordered => 1 } );
        $first->form = $categorystr . $first->form;
        $first->lemma = $categorystr . $first->lemma;
    }

    return 1;
}

1;

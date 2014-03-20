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
    isa => 'Str',
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
  price => "price",
  food => "food",
  service => "service", 
  ambience => "ambience",
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
    $self->{wn_instance} = WordNet::QueryData->new( $wn_realpath . "/" );

    return 1;
}

sub _get_all_hyperonyms {
    my ( $self, $node ) = @_;
    return if $node->tag !~ m/^N/; # only handle nouns
    my @queue = $self->{wn_instance}->querySense( $node->lemma . "#n" );
    my %hyperonyms;
    while ( @queue ) {
        my $current = shift @queue;
        $hyperonyms{ $current } = 1;
        my @hyper = grep { ! $hyperonyms{ $_ } && ! m/^entity/ }
            $self->{wn_instance}->querySense( $current, "hype" );
        push @queue, @hyper;
    }

    my @stripped;
    for my $hyper (keys %hyperonyms) {
        $hyper =~ s/#.*//;
        push @stripped, $hyper;
    }
    log_info "Hyperonyms for $node->{lemma}: " . join(" ", @stripped);
    return @stripped;
}

sub process_atree {
    my ( $self, $atree ) = @_;
    my %polarities;
    for my $node ( grep { $self->is_aspect_candidate( $_ ) } $atree->get_descendants ) {
        log_info "Processing node $node->{lemma}";
        my $polarity = $self->combine_polarities( $self->get_aspect_candidate_polarities( $node ) );
        if ( $exceptions{ lc( $node->form ) } ) {
            log_info "Found form in exceptions";
            push @{ $polarities{ $exceptions{ lc( $node->form ) } } }, $polarity;
        } elsif ( $exceptions{ $node->lemma } ) {
            log_info "Found lemma in exceptions";
            push @{ $polarities{ $exceptions{ $node->lemma } } }, $polarity;
        } else {
            log_info "Looking up hyperonyms";
            my @hypers = grep { $known{ $_ } } $self->_get_all_hyperonyms( $node );
            if ( @hypers ) {
                log_info "Found known hyperonym, marking node";
                # let's just take the first known hyperonym
                push @{ $polarities{ $known{ $hypers[0] } } }, $polarity;
            } else {
                log_info "No known hyperonym";
                push @{ $polarities{ "anecdotes/miscellaneous" } }, $polarity;
            }
        }
    }

    if ( %polarities ) {
        my $categorystr = "#CAT#";

        for my $category ( keys %polarities ) {
            my $polarity = $self->combine_polarities( @{ $polarities{ $category } } );
            $categorystr .= "$category^$polarity ";
        }
        $categorystr .= "#";

        # let's just rudely prepend our annotation to the first word
        my ( $first ) = $atree->get_descendants( { ordered => 1 } );
        $first->{form} = $categorystr . $first->form;
        $first->{lemma} = $categorystr . $first->lemma;
    }

    return 1;
}

1;

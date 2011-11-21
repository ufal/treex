package Treex::Tool::Coreference::InterSentLinks;

use Moose;
use Treex::Core::Common;

has 'doc' => (
    is          => 'ro',
    isa         => 'Treex::Core::Document',
    required    => 1,
);

has 'type' => (
    is          => 'ro',
    isa         => enum( [qw/gram text all/] ),
    required    => 1,
    default     => 'all',
);

has 'interlinks' => (
    is          => 'ro',
    isa         => 'ArrayRef[HashRef[ArrayRef[Str]]]',
    required    => 1,
    lazy        => 1,
    builder     => '_build_interlinks',
);

has language => ( is => 'rw', isa => 'Treex::Type::LangCode', required => 1 );
has selector => ( is => 'rw', isa => 'Treex::Type::Selector', default => '' );

sub BUILD {
    my ($self) = @_;

    $self->interlinks;
}

sub _build_interlinks {
    my ($self) = @_;

    my @interlinks = ();

    # id -> bool: processed nodes
    my %processed_node_ids = ();
    # ante_id -> [ anaph_id ]: links, which refers to a so far not visited antecedent
    my %non_visited_ante_ids = ();

    # process nodes in the reversed order
    foreach my $bundle (reverse $self->doc->get_bundles) {

        my %local_non_visited_ante_ids = %non_visited_ante_ids;

        my $tree = $bundle->get_tree($self->language, 't', $self->selector);
        
        foreach my $node (reverse $tree->get_descendants({ ordered => 1 })) {
            
            # remove links where $node is an antecedent
            foreach my $ante_id (keys %local_non_visited_ante_ids) {
                if ($node->id eq $ante_id) {
                    delete $local_non_visited_ante_ids{$ante_id};
                }
            }

            # get antes
            my @antes = ();
            if ($self->type eq 'gram') {
                @antes = $node->get_coref_gram_nodes;
            }
            elsif ($self->type eq 'text') {
                @antes = $node->get_coref_text_nodes;
            }
            else {
                @antes = $node->get_coref_nodes;
            }

            # skip cataphoric links
            my @non_cataph = grep {!defined $processed_node_ids{$_->id}} @antes;
            # new links
            foreach my $ante (@non_cataph) {
                push @{$local_non_visited_ante_ids{$ante->id}}, $node->id;
            }
            
            $processed_node_ids{ $node->id }++;
        }

        #print STDERR Dumper(\%local_non_visited_ante_ids);

        # store the number of links from this tree to previous ones
        unshift @interlinks, \%local_non_visited_ante_ids;
        # retain the unresolved links
        %non_visited_ante_ids = %local_non_visited_ante_ids;
    }

    # the first element should be always empty => all antecedents have been found
    # shift @interlinks;
    return \@interlinks;
}

sub counts {
    my ($self) = @_;

    my @counts = ();

    foreach my $hash (@{$self->interlinks}) {
        # $hash : { ante_id => [ anaph_id ] }
        my $sum = 0;
        foreach my $ante_id (keys %$hash) {
            my $anaphs = $hash->{$ante_id};
            $sum += @$anaphs;
        }
        push @counts, $sum;
    }

    return @counts;
}

sub remove_selected {
    my ($self, $break_idx_list) = @_;
    
    my $doc = $self->doc;
    my $interlinks = $self->interlinks;

    foreach my $i (@$break_idx_list) {

        my $local_links = $interlinks->[$i];
        
        # segments are interlinked
        foreach my $ante_id (keys %$local_links) {
            my $anaph_ids = $local_links->{$ante_id};

            foreach my $anaph_id (@$anaph_ids) {
                my $anaph = $doc->get_node_by_id( $anaph_id );
                my $ante  = $doc->get_node_by_id( $ante_id  );
                
                # remove the coref link from anaph to ante
                $anaph->remove_coref_nodes( $ante );
            }
        }
    }
}

1;

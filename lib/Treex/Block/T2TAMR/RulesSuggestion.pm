package Treex::Block::T2TAMR::RulesSuggestion;
# usage: treex Read::Treex from=csen.merged.treex.gz T2TAMR::AmrConvertor language=cs rules_file=corpus.tamr.gz [verbalization_file=N_V.txt] Write::Treex to=csen.merged.with_tamr.treex.gz

use Moose;
use Treex::Core::Common;
use Unicode::Normalize;

use File::Slurp;

extends 'Treex::Core::Block';

has '+language'       => ( required => 1 );

sub process_document {
    my ( $self, $document ) = @_;
    my $active_rule_label = qw(active_query);
    foreach my $bundle ( $document->get_bundles() ) {
        my $zone = $bundle->get_zone( $self->language);
        my $root = $zone->get_ttree;
        foreach my $node ($root->get_descendants){
          if ($node->wild->{'query_label'}) {
            my $activequery = '';
            my $activequerynodescount = 0;
            foreach my $query (keys %{$node->wild->{'query_label'}}) {
              if ($active_rule_label !~~ @{$node->wild->{'query_label'}->{$query}}){
                my $querynodescount = 1;
                foreach my $temp_node ($root->get_descendants){
                  if ($temp_node ne $node && defined $temp_node->wild->{'query_label'}->{$query}){
                    $querynodescount++;
                  }
                }
                if ($querynodescount > $activequerynodescount){
                  $activequery = $query;
                  $activequerynodescount = $querynodescount;
                }
              }
            }
            if ($activequery ne ''){
              print STDERR "Active query $activequery\n";
              foreach my $temp_node ($root->get_descendants){
                if (defined $temp_node->wild->{'query_label'}->{$activequery}){
                  push @{$temp_node->wild->{'query_label'}->{$activequery}}, $active_rule_label;
                }
              }
            }
          }
        }
    }
}

1;

=over

=item Treex::Block::T2TAMR::RulesSuggestion

Dumb rules suggestion for PMLTQ-marked nodes. The more nodes the rule covers, the better rule is

=back

=cut

# Copyright 2014

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

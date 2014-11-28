package Treex::Block::Util::PMLTQMark;

use Moose;
use Treex::Core::Common;

use Treex::Tool::PMLTQ::Query;
use Tree_Query::Common;
use Treex::PML::Factory;
use File::Slurp;

extends 'Treex::Core::Block';

has 'query_file' => ( isa => 'Maybe[Str]', is => 'ro' );

has 'queries' => ( is => 'ro', isa => 'Treex::PML::Document', builder => '_load_queries', lazy => 1 );

sub _load_queries {
    
    my ($self) = @_;
    
    if ( !defined($self->query_file) ){
        log_fatal('\'query_file\' must be defined!');
    }
    
    my $doc = Treex::PML::Factory->createDocumentFromFile($self->query_file);   
    return $doc;
}

sub process_document {

    my ( $self, $document ) = @_;
    
    for my $query_tree ($self->queries->trees) {
        #log_info Tree_Query::Common::as_text($query_tree);
        
        my $evaluator;
        eval {
            $evaluator = Treex::Tool::PMLTQ::Query->new( $query_tree, { treex_document => $document } );
            1;
        } or next;

        my $query_id = $query_tree->attr('id');
        my %pos2name;
        while (my ($key, $value) = each %{$evaluator->{name2match_pos}}) {
            $pos2name{$value}=$key;
        }
        my $query_count = 0;
        while ( my $res = $evaluator->find_next_match() ) {
          my $pos = 0;
          my $query_label = $query_id . ($query_count > 0 ? '-' . $query_count : '' );
          my $minimal_depth = 99999;
	  my $ttree_id = 0;
	  print "$query_id\t";
          $query_count++;
	  my $nodecount = 0;
          my @node_ids;
	  for my $node (@$res) {
	    if (!$ttree_id) {
	      $ttree_id = $node->get_zone()->get_ttree()->id; 
	      print "$ttree_id\t";
	    }
            push @{$node->wild->{"query_label"}->{$query_label}} => $pos2name{$pos};
            $node->serialize_wild();
            $minimal_depth = $node->get_depth if $node->get_depth < $minimal_depth;
            $nodecount++;
	    $pos += 1;
            push @node_ids, $node->id;
	  }
          print "$nodecount\t";
	  for my $node (@$res) {
            if ($node->get_depth == $minimal_depth) {
              push @{$node->wild->{"query_label"}->{$query_label}} => 'queryroot';
              $node->serialize_wild();
    	      print $node->id . "\t";
            }
          }
	  print join("\t", @node_ids) . "\n";
        }
    }
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Treex block to mark nodes, found with PMLTQ query. Output lines in the following format:
"QUERY_NAME \t T-tree-id \t queryroot-node-id \t marked-node-ids-joined-with-\t"

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

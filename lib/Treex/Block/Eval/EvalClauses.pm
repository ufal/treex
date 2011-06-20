package Treex::Block::Eval::EvalClauses;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'source_selector' => ( is       => 'rw', isa => 'Str', default => 'test' );
has 'ignore_nonverbal' => ( is      => 'rw', isa => 'Bool', default => 0 );

binmode STDOUT, ":utf8";

my ($hits, $test_count, $gold_count) = (0, 0, 0);

sub process_bundle {
    my ( $self, $bundle ) = @_;

    
    my $gold_zone = $bundle->get_zone( $self->language, $self->selector );
    my $gold_root = $gold_zone->get_atree;
    
    my $test_zone = $bundle->get_zone( $self->language, $self->source_selector );
    my $test_root = $test_zone->get_atree;

    my $gold_rf = _clauses_as_concat_ids ( $gold_root, 'id' );
    my $test_rf = _clauses_as_concat_ids ( $test_root, 'alignment/counterpart.rf' );

    if( scalar keys %{$gold_rf} < 1 ){
      log_info ( "No gold clauses. Skipping sentence " . $gold_root->id );
      return;
    }

    if ($self->ignore_nonverbal and not grep { $_->tag =~ /^V[Bpi]/} $gold_root->get_descendants) {
      log_info ( "Sentence fragment. Skipping sentence." . $gold_root->id );
      return;
    }

    $test_count += scalar keys %{$test_rf};
    $gold_count += scalar keys %{$gold_rf};
    
    foreach my $clause ( keys %{$test_rf} ) {
        if($gold_rf->{$clause}) {
            $hits += 1;
        }
        else {
            $clause =~ /^([^\|]+)/;
            my $filelist_item = $bundle->get_document->full_filename . '.treex#' . $1;
            print( $filelist_item,"\n");
        }
    }
}

sub _clauses_as_concat_ids {
    my ($root, $id_path) = @_;

    my @clauses = ();

    foreach my $node ( $root->get_descendants( { ordered => 1 } ) ) {
      my $num = $node->{clause_number};
      next if not defined $num;
      push @{ $clauses[$num] }, $node;
    }

    my %ret = ();  
    foreach my $clause ( @clauses ) {
        my $key = join ( '|', map { $_->attr( $id_path ) } @{$clause} );
        $ret { $key } = 1;
        #print $key, "\n";
    }

    return \%ret;
}

END {
  print {*STDERR} "$hits $test_count $gold_count\n";
  my ($p, $r) = (
    $hits / $test_count,
    $hits / $gold_count,
  );
  printf {*STDERR} "P = %.4f\nR = %.4f\nF = %.4f\n\n", $p, $r, 2*$p*$r/($p+$r); 
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Eval::EvalClauses

=head1 DESCRIPTION

This block evaluates clauses in two aligned bundle zones.

=head1 PARAMETERS

=over

=item C<language>

Language.

=item C<selector>

Gold standard zone selector.

=item C<source_selector>

Selector of the zone to be evaluated. Nodes of the zone have to be aligned to the gold-standard ones.

=back

=head1 AUTHOR

Jan Popelka <popelka@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

package Treex::Block::A2W::ShowIT;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ($self, $zone) = @_;
    my $bundle = $zone->get_bundle();
    my $entities_ref = $bundle->wild->{entities};
    my $src_zone = $bundle->get_zone('en', 'src');
    
    my $re_src_sentence = reconstruct_entities($src_zone->sentence, $entities_ref);
    $src_zone->set_sentence($re_src_sentence);
    print STDERR "New src snt: $re_src_sentence\n";

    my $re_tst_sentence = reconstruct_entities($zone->sentence, $entities_ref);
    $zone->set_sentence($re_tst_sentence);

    print STDERR "Original snt: ",  $bundle->wild->{original_sentence},"\n";
    print STDERR "New tst snt: $re_tst_sentence\n";
    return;
}

sub reconstruct_entities {
  my $in_sentence = shift;
  my $entites_ref = shift;
  my $out_sentence = $in_sentence;
  print STDERR "Replacing sent: $in_sentence\n";
  foreach my $cmd (@{$entites_ref->{'commands'}}){
    print STDERR "Before $cmd: $in_sentence\n";
    $in_sentence =~ s/xxxCMDxxx/$cmd/i;
    print STDERR "After: $in_sentence\n";
  }
  if (defined($entites_ref->{'entities'})){
    foreach my $entity (@{$entites_ref->{'entities'}}){
      print STDERR "Before $entity: $in_sentence\n";
      $in_sentence =~ s/xxxNExxx/$entity/i;
      print STDERR "After: $in_sentence\n";
    }
  }
  if (defined($entites_ref->{'urls'})){
    print STDERR "Restoring URLs:\n";
    foreach my $entity (@{$entites_ref->{'urls'}}){
      print STDERR "Before $entity: $in_sentence\n";
      $in_sentence =~ s/xxxURLxxx/$entity/i;
      print STDERR "After: $in_sentence\n";
    }
  }
  $in_sentence =~ s/\s+/ /g;
  $in_sentence =~ s/^ *//g;
  $in_sentence =~ s/ *$//g;
  return $in_sentence;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2W::ShowIT - show entites hidden from tokenizer

=head1 DESCRIPTION

=head1 OVERRIDEN METHODS

=head2 from C<Treex::Core::Block>

=over 4

=item process_atree

=back

=head1 AUTHOR

Roman Sudarikov <sudarikov@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2009 - 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


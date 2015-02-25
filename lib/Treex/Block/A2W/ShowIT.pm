package Treex::Block::A2W::ShowIT;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has source_selector => (is => 'ro', default=>'src');

sub process_zone {
    my ($self, $zone) = @_;
    my $bundle = $zone->get_bundle();
    my $entities_ref = $bundle->wild->{entities};
    my $src_zone = first {$_->selector eq $self->source_selector} $bundle->get_all_zones();          
    log_fatal 'No zone with selector '. $self->source_selector if !$src_zone;

    my $re_tst_sentence = reconstruct_entities($zone->sentence, $entities_ref);
    $re_tst_sentence = fix_quotes($re_tst_sentence);
    $zone->set_sentence($re_tst_sentence);

    $src_zone->set_sentence($bundle->wild->{original_sentence}) if $bundle->wild->{original_sentence};
    log_debug "New tst snt: $re_tst_sentence\n";
    return;
}

sub fix_quotes {
  my $sentence = shift;
  $sentence =~ s/“([^”]+?)”/„$1“/ig;
  return $sentence;      
}

sub reconstruct_entities {
  my $in_sentence = shift;
  my $entites_ref = shift;
  my $out_sentence = $in_sentence;
  log_debug "Replacing sent: $in_sentence\n";
  if (defined($entites_ref->{'commands'})){
    log_debug "Restoring commands:\n";
    foreach my $cmd (@{$entites_ref->{'commands'}}){
      log_debug "Before $cmd: $in_sentence\n";
      $in_sentence =~ s/xxxCMDxxx/$cmd/i;
      log_debug "After: $in_sentence\n";
    }
  }
  if (defined($entites_ref->{'entities'})){
    log_debug "Restoring entites:\n";
    foreach my $entity (@{$entites_ref->{'entities'}}){
      log_debug "Before $entity: $in_sentence\n";
      $in_sentence =~ s/xxxNExxx/$entity/i;
      log_debug "After: $in_sentence\n";
    }
  }  
  if (defined($entites_ref->{'mails'})){
    log_debug "Restoring mails:\n";
    foreach my $entity (@{$entites_ref->{'mails'}}){
      log_debug "Before $entity: $in_sentence\n";
      $in_sentence =~ s/xxxMAILxxx/$entity/i;
      log_debug "After: $in_sentence\n";
    }
  }
  if (defined($entites_ref->{'urls'})){
    log_debug "Restoring URLs:\n";
    foreach my $entity (@{$entites_ref->{'urls'}}){
      log_debug "Before $entity: $in_sentence\n";
      $entity =~ m/<IT type=".*?">(.*?)<\/IT>/;
      my $originalUrl = $1;
      if (!$1){
        log_debug "No url in $entity\n";
      }
      $in_sentence =~ s/xxxURLxxx/$originalUrl/i;
      log_debug "After: $in_sentence\n";
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


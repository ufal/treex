package Treex::Block::A2W::ShowIT;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Moses;

has source_selector => (is => 'ro', default=>'src');

has set_original_sentence => ( is => 'rw', isa => 'Bool', default => 1 );

has moses_xml => ( is => 'rw', isa => 'Bool', default => 0 );

has prob => ( is => 'rw', isa => 'Str', default => '0.8' );

sub process_zone {
    my ($self, $zone) = @_;
    my $bundle = $zone->get_bundle();
    my $entities_ref = $bundle->wild->{entities};
    my $src_zone = first {$_->selector eq $self->source_selector} $bundle->get_all_zones();          
    log_fatal 'No zone with selector '. $self->source_selector if !$src_zone;

    my $re_tst_sentence = $self->reconstruct_entities($zone->sentence, $entities_ref);
    $re_tst_sentence = fix_quotes($re_tst_sentence);
    $zone->set_sentence($re_tst_sentence);

    if ($self->set_original_sentence) {
        $src_zone->set_sentence($bundle->wild->{original_sentence}) if $bundle->wild->{original_sentence};
    }
    log_debug "New tst snt: $re_tst_sentence\n";
    return;
}

sub fix_quotes {
  my $sentence = shift;
  $sentence =~ s/“([^”]+?)”/„$1“/ig;
  return $sentence;      
}

sub reconstruct_entities {
  my ($self, $in_sentence, $entites_ref) = @_;
  log_debug "Replacing sent: $in_sentence\n";

  my %array_entities = (
      commands => 'xxxCMDxxx',
      entities => 'xxxNExxx',
      mails => 'xxxMAILxxx',
  );
  foreach my $entity_type (keys %array_entities) {
      if (defined($entites_ref->{$entity_type})){
          log_debug "Restoring $entity_type:\n";
          foreach my $replacement (@{$entites_ref->{$entity_type}}){
              $in_sentence = $self->replace($in_sentence, $array_entities{$entity_type}, $replacement);
          }
      }
  }
  
  foreach my $block (qw (upaths wpaths files)){
    if (defined($entites_ref->{$block})){
      log_debug "Restoring paths:\n";
      foreach my $entity_key (keys %{$entites_ref->{$block}}){
        my $upath = $entites_ref->{$block}{$entity_key};
        $in_sentence = $self->replace($in_sentence, $entity_key, $upath);
      }
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
      $in_sentence = $self->replace($in_sentence, 'xxxURLxxx', $originalUrl);
    }
  }

  $in_sentence =~ s/\s+/ /g;
  $in_sentence =~ s/^ *//g;
  $in_sentence =~ s/ *$//g;
  return $in_sentence;
}

sub replace {
    my ($self, $in_sentence, $search, $replacement) = @_;

    log_debug "Before $replacement: $in_sentence\n";
    if ($self->moses_xml) {
        $replacement = '<item'
            . ' translation="' . Treex::Tool::Moses::escape($replacement)
            . '" prob="' . $self->prob . '">'
            . Treex::Tool::Moses::escape($replacement)
            . '</item>';
    }
    $in_sentence =~ s/$search/$replacement/i;
    log_debug "After: $in_sentence\n";

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


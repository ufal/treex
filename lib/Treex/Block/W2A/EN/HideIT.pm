package Treex::Block::W2A::EN::HideIT;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ($self, $zone) = @_;
    my ($changed_sentence, $entities_ref) = $self->substitute_entities($zone->sentence);
    $zone->get_bundle()->wild->{original_sentence} = $zone->sentence;
    #log_debug "New snt: $changed_sentence\n";
    $zone->set_sentence($changed_sentence);
    $zone->get_bundle()->wild->{entities} = $entities_ref;
    log_debug "Ents for $changed_sentence:\n", join (", ", @{$entities_ref->{'entities'}}), "\n";
    return;
}

sub substitute_entities {
  my ($self, $sentence) = @_;
  #my $sentence = shift;
  my $new_sentence = $sentence;
  my @entities;
  my @commands;
  my @urls;
  my @mails;
  $sentence = lcfirst($sentence);
  $sentence =~ s/$/ /;
  $sentence =~ s/^/ /;
  #Http(s) fix
  #$sentence =~ s|(?<!\s)(https?://)| $1|g
  #$sentence =~ s/(["<>{}“”«»–|—„‚‘]|\[|\]|``|\'\'|‘‘|\^)/ $1 /g;
  my $quotes = [
    {start => '"', end =>'"'}, 
    {start => "'", end =>"'"}, 
    {start => '“', end =>'”'}, 
    {start => '«', end =>'»'},
    {start => '„', end =>'“'},
    {start => '‚', end =>'‘'},    
    {start => '``', end =>'``'}
  ];
  log_debug "Collecting cmds...\n";  
  foreach my $quote (@$quotes){
    my $start = $quote->{start};
    my $end = $quote->{end};
    while($sentence =~ s/($start)([a-z][^$end<]+?)([$end|<])/$1XXXCMDXXX$3/){
      my $cmdString = $2;
      push(@commands, $cmdString);
      log_debug "Cmd: $cmdString\n";
    }  
  }
  $sentence = $self->_mark_urls($sentence);
  while($sentence =~ s/(<IT type=".*?">.*?<\/IT>)/xxxURLxxx/){
    push(@urls, $1);
    #log_debug "Entity: $2\n";
  }
  while($sentence =~  s/([\w0-9._%+-]+@[^\s]+?)(\s)/xxxMAILxxx$2/){
  # This wold be more strict regexp for emails
  #s/([\w0-9._%+-]+@[^.]+\.[[:alpha:]]{2,4})(\s)/xxxMAILxxx$2/){
    push(@mails, $1);
    #log_debug "Mail: $1\n";
  }
  $sentence =~ s/^\s+//;
  $sentence = ucfirst($sentence);
  #log_debug "Collecting entites...\n";
  #while($sentence =~ s/(["<>{}“”«»–|—„‚‘\s]|\[|\]|``|\'\'|‘‘|\^)([A-Z][a-z]+)/$1xxxNExxx/){
    #push(@entities, $2);
    #log_debug "Entity: $2\n";
  #}
  if (scalar @urls > 0){
    log_debug "In $sentence:\nFound urls:", join("\t", @urls), "\n";  
    #die;
  }
  return ($sentence, {entities=> \@entities, commands=> \@commands, urls => \@urls, mails => \@mails});
}

use URI::Find::Schemeless;
my $finderUrl = URI::Find::Schemeless->new(sub {
    my ($uri, $orig_uri) = @_;
    return '<IT type="url">' . $orig_uri . '</IT>';
});

use Email::Find;
my $finderMail = Email::Find->new(sub {
    my ($mail, $orig_mail) = @_;
    return '<IT type="mail">' . $orig_mail . '</IT>';
});
sub _mark_urls {
    my ( $self, $sentence ) = @_;
    $finderUrl->find(\$sentence);
    #$finderMail->find(\$sentence);
    return $sentence;
}
1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::EN::HideNE - hide some entites from tokenizer

=head1 DESCRIPTION

All hidden entites are stored in the bundle's wild attr. 


=head1 OVERRIDEN METHODS

=head2 from C<Treex::Core::Block>

=over 4

=item process_atree

=back

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2009 - 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


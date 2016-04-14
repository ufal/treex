package Treex::Block::W2A::HideIT;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has use_alphabetic_indexes => ( is => 'rw', isa => 'Bool', default => 0 );
my @alphabet = ("aa".."zz");

sub index {
    my ($self, $index) = @_;

    if ($self->use_alphabetic_indexes) {
        return $alphabet[$index];
    } else {
        return $index;
    }
}

sub process_zone {
    my ($self, $zone) = @_;
    my ($changed_sentence, $entities_ref) = $self->substitute_entities($zone->sentence);
    $zone->get_bundle()->wild->{original_sentence} = $zone->sentence;
    $zone->set_sentence($changed_sentence);
    $zone->get_bundle()->wild->{entities} = $entities_ref;
    log_debug "Ents for $changed_sentence:\n", join (", ", @{$entities_ref->{'entities'}}), "\n";
    return;
}

sub substitute_entities {
  my ($self, $sentence) = @_;
  my $new_sentence = $sentence;
  my @entities;
  my @commands;
  my @urls;
  my @mails;
  my %wpaths;
  my %upaths;
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
	# Very crude heuristics:
	# 1. Anything between quotes which starts with lowercase is considered a command.
	# 2. Commands may contain <name of the folder> parts, which should be translated,
	#    i.e. we don't want to include them in the command to be hidden.
	#    Currently, we stop the command before first "<" (and don't mark the rest of the command).
	# 3. We require a space (or start of string) before the opening quote.
	#    This is to exclude sentences with two contractions,
	#    e.g. "Don't mark it if you aren't sure." should not end as "Don'XXXCMDXXX't sure."
    while($sentence =~ s/(^| )($start)([a-z][^$end<]+?)($end|<)/$1$2XXXCMDXXX$4/){
      my $cmdString = $3;
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
  #while($sentence =~  s/(\s)([~|\/]{1,2}[^\/]+?\/[^\/]+\/?)(\s)/$1xxxUPATHxxx$3/){
    #push(@upaths, $2);
    #log_debug "Mail: $1\n";
  #}

  # Unix paths
  my @possible_paths = $sentence =~ /\s([~|\/]{1,2}[^\/]+?\/[^\/]+\/[^\s()]+)[\s()]/g;
  my $count = 1;
  foreach my $posible_path (@possible_paths){
    if (not (scalar split (/\s/, $posible_path) > scalar split (/\\/, $posible_path))) {
      my $replace = "xxxUPATH" . $self->index($count) . "xxx";
      $sentence =~ s/\Q$posible_path\E/$replace/;
      $upaths{$replace} = $posible_path;
      $count++;
    }
  }
  #while($sentence =~  /(\s)([A-Z]?:?\\?\\[^\\]+\\?)(\s)/){
    #my $possible_path = $2;
    #if (scalar split "\s" $possible_path > )
    #push(@wpaths, $2);
    #log_debug "Mail: $1\n";
  #}

  # Windows paths
  @possible_paths = $sentence =~ /\s([A-Z]?:?\\?\\[^\\]+?\\[^\\]+?\\[^\s()])[\s()]/g;
  $count = 1;
  foreach my $posible_path (@possible_paths){
    if (not (scalar split (/\s/, $posible_path) > scalar split (/\\/, $posible_path))) {
      my $replace = "xxxWPATH" . $self->index($count) . "xxx";
      $sentence =~ s/\Q$posible_path\E/$replace/;
      $wpaths{$replace} = $posible_path;
      $count++;
    }
  }
  my %files;
  my @possible_filenames = $sentence =~ /\s([A-Za-z0-9_\-\.]+\.\w{3})\s/g;
  $count = 1;
  foreach my $posible_file (@possible_filenames){
    if (length $posible_file > 4) {
      my $replace = "xxxPFILENAME" . $self->index($count) . "xxx";
      $sentence =~ s/$posible_file/$replace/;
      $files{$replace} = $posible_file;
      $count++;
    }
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
  return ($sentence, {entities=> \@entities, commands=> \@commands, urls => \@urls, mails => \@mails, upaths => \%upaths, wpaths => \%wpaths, files => \%files});
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

Treex::Block::W2A::HideIT - hide IT-domain entites

=head1 DESCRIPTION

Named entites from the IT domain (URLs, emails, Unix commands, Windows/Unix paths,...)
are heuristically (based on quotes etc.) detected in C<$zone->sentence>
and replaced with placeholders I<xxxURLxxx>, I<xxxMAILxxx> etc.
The original sentence is backed up in C<$bundle->wild->{original_sentence}>
and the extracted entites are stored in  C<$bundle->wild->{entites}>. 

=head1 AUTHOR

Roman Sudarikov <sudarikov@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

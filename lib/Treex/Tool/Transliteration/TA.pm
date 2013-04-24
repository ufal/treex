package Treex::Tool::Transliteration::TA;
use Treex::Core::Common;

use Moose;

has 'data_dir' =>
  ( isa => 'Str', is => 'ro', default => 'data/models/transliteration/ta' );

has 'enc_map' => (
	traits  => ['Array'],
	isa     => 'ArrayRef',
	is      => 'rw',
	default => sub { [] },
	handles => {
		add_map_entry  => 'push',		
		clear_enc_map => 'clear',
	}
);

has 'use_enc_map' => (
	isa     => 'Str',
	is      => 'rw',
	trigger => \&load_enc_map,
	writer  => 'set_enc_map'
);

has 'known_maps' => (
	isa     => 'HashRef',
	is      => 'ro',
	default => sub {
		{
			'utf8_2_latin' => 'utf8_2_latin.dat',
			'latin_2_utf8' => 'latin_2_utf8.dat'
		};
	}
);

sub load_enc_map {
	my ( $self, $m ) = @_;

	my $map_value = $self->known_maps->{$m};
	my $map_file =
	  require_file_from_share( $self->data_dir . '/' . $map_value );
	open( RH, '<:encoding(utf8)', $map_file )
	  or die "Error: cannot open the mapfile: $map_file\n";
	my @DATA = <RH>;
	close RH;

	# clear the existing map
	$self->clear_enc_map();

	foreach my $line (@DATA) {
		chomp $line;
		$line =~ s/(^\s+|\s+$)//;
		next if $line =~ /^$/;
		next if $line =~ /\#/;
		if ($line =~ /\t+:\t+/) {
			my @e1_e2 = split(/\t+:\t+/, $line);
			$e1_e2[0] =~ s/\s+//g;
			$e1_e2[1] =~ s/\s+//g;
			if (scalar(@e1_e2) == 2) {
				$self->add_map_entry(\@e1_e2);
			}
		}
	}
	return;
}

sub transliterate_string {
	my ($self, $input_string)= @_;
	my $output_string = $input_string;
	my @map_entries = @{$self->enc_map};	
	foreach my $entry_ref (@map_entries) {
		my @str = @{$entry_ref};
		$output_string =~ s/$str[0]/$str[1]/g;
	}
	return $output_string;
}

1;

__END__

=pod

=head1 NAME

Treex::Tool::Transliteration::TA - Tamil Transliterator

=head1 SYNOPSIS

	use utf8;
	use Treex::Tool::Transliteration::TA;

    binmode STDIN, ':encoding(utf8)';
    binmode STDOUT, ':encoding(utf8)';
	binmode STDERR, ':encoding(utf8)';

	my $transliterator = Treex::Tool::Transliteration::TA->new(use_enc_map => 'latin_2_utf8');
	    
    my $inp_str1 = 'cek kutiyaracu';
    my $inp_str2 = 'செக் குடியரசு';
    
    # To transliterate from latin to utf8
    my $out_str1 = $transliterator->transliterate_string($inp_str1);

    # To transliterate from  utf8 to latin
    $transliterator->set_enc_map('utf8_2_latin');
    my $out_str2 = $transliterator->transliterate_string($inp_str2);
    
    print "Input 1: $inp_str1 ,\t\t Output 1: $out_str1\n";
    print "Input 2: $inp_str2 ,\t\t Output 2: $out_str2\n";

=head1 TODO

Transliteration has to be more generalized.


=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010, 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

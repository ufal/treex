package Treex::Tool::FormsGenerator::Tamil;
use Treex::Core::Common;

use Moose;

has 'use_template' => (
	is      => 'rw',
	isa     => 'Str',
	trigger => \&load_template,
	writer	=> 'set_template',
);

# prefixes are not supported at the moment
has 'prefix_list' => (
	is      => 'rw',
	isa     => 'ArrayRef[Str]',
	default => sub { [] },
);

has 'suffix_list' => (
	traits  => ['Array'],
	is      => 'rw',
	isa     => 'ArrayRef',
	default => sub { [] },
	handles => {
		add_suffix  => 'push',
		num_suffixes => 'count',
		suffixes     => 'elements',
		get_suffix  => 'get',
		set_suffix	=> 'set',	
		empty_suffix_list	=> 'clear',	
	}
);

has 'known_templates' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub {
		{ 	
			# major types
			'verb_type1' => "data/models/forms/ta/verbs/type1.dat", 
			'verb_type2' => "data/models/forms/ta/verbs/type2.dat",
			'verb_type3' => "data/models/forms/ta/verbs/type3.dat",
 			'verb_type4' => "data/models/forms/ta/verbs/type4.dat",
 			'verb_type5' => "data/models/forms/ta/verbs/type5.dat",
 			'verb_type6' => "data/models/forms/ta/verbs/type6.dat",
 			'verb_type7' => "data/models/forms/ta/verbs/type7.dat",
 			# specific types
			'verb_type2a' => "data/models/forms/ta/verbs/type2a.dat",
			'verb_type_cey' => "data/models/forms/ta/verbs/type_cey.dat",
			'verb_type_cel' => "data/models/forms/ta/verbs/type_cel.dat",
			'verb_type_varu' => "data/models/forms/ta/verbs/type_varu.dat",
			'verb_type_po' => "data/models/forms/ta/verbs/type_po.dat",			
		};		
	}
);

has 'rewrite_rules' => (
	traits  => ['Array'],
	is      => 'rw',
	isa     => 'ArrayRef',
	default => sub { [] },
	handles => {
		add_rule  => 'push',
		num_rules => 'count',
		rules     => 'elements',
		get_rule  => 'get',
		set_rule	=> 'set',
		empty_rules	=> 'clear',		
	},
);

# Tamil alphabets
my $VOWEL_SIGNS = qr/ா|ி|ீ|ு|ூ|ெ|ே|ை|ொ|ோ|ௌ/;
my $VOWELS	= qr/அ|ஆ|இ|ஈ|உ|ஊ|எ|ஏ|ஐ|ஒ|ஓ|ஔ/;
my $CONSONANTS = qr/க்|ங்|ச்|ங்|ட்|ண்|த்|ந்|ப்|ம்|ய்|ர்|ல்|வ்|ள்|ழ்|ற்|ன்/;
my $SHORT_VOWEL_SIGNS = qr/ி|ு|ெ|ை|ொ|ௌ/;
my $LONG_VOWEL_SIGNS = qr/ா|ீ|ூ|ே|ோ/;

sub load_template {
	my ( $self, $new_type, $old_type ) = @_;
	
	# clear the previously loaded template
	$self->empty_suffix_list();
	$self->empty_rules();
	
	my $template_file = require_file_from_share(
		$self->known_templates()->{ $self->use_template } );
	open( RHANDLE, '<:encoding(utf8)', $template_file );
	my @data = <RHANDLE>;
	close RHANDLE;
	my %variables;
	foreach my $line (@data) {
		chomp $line;
		$line =~ s/(^\s+|\s+$)//;
		next if ( $line =~ /^$/ );
		next if ( $line =~ /^#/ );

		# 1. variables
		if ( $line =~ /=/ ) {
			my @var_val = split( /\s*=\s*/, $line );
			$variables{ $var_val[0] } = $var_val[1];
		}
		# 2. rules
		elsif ( $line =~ /::/ ) {
			my @rules_pat_sub = split( /\t+::\t+/, $line );
			next if ( scalar(@rules_pat_sub) != 2 );
			$rules_pat_sub[0] =~ s/(^\s+|\s+$)//;
			$rules_pat_sub[1] =~ s/(^\s+|\s+$)//;
			my @tmp1 = split( /\t+/, $rules_pat_sub[0] );
			my @tmp2 = split( /\t+/, $rules_pat_sub[1] );
			my $stem_pat   = $tmp1[0];
			my $suff_pat   = $tmp1[1];
			my $stem_sub   = $tmp2[0];
			my $suff_sub   = $tmp2[1];
			my @rule_parts = ( $stem_pat, $suff_pat, $stem_sub, $suff_sub );
			$self->add_rule( \@rule_parts );
		}
		# 3. suffixes
		else {
			$self->add_suffix($line);
		}
	}
	# replace variables with variable values
	foreach my $i ( 0 .. $self->num_rules - 1 ) {
		my $r        = $self->get_rule($i);
		my @tmp      = @{$r};
		my $stem_pat = $tmp[0];
		my $suff_pat = $tmp[1];
		my $new_stem_pat = $stem_pat;
		my $new_suff_pat = $suff_pat;
		foreach my $v ( keys %variables ) {
			my $val = $variables{$v};
			$new_stem_pat =~ s/[\%]$v/$val/g;
			$new_suff_pat =~ s/[\%]$v/$val/g;
		}
		my @new_rule = ($new_stem_pat, $new_suff_pat, $tmp[2], $tmp[3]);
		$self->set_rule($i, \@new_rule);
	}
}

sub generate_forms {
	my ($self, $lemma) = @_;
	#my @forms = ($lemma);	
	my @forms = ();
	foreach my $su ($self->suffixes) {
		my $lcopy = $lemma;
		foreach my $r ($self->rules) {
			my @tmp = @{$r};
			my $stem_pat = $tmp[0];
			my $suff_pat = $tmp[1];			
			my $stem_sub   = $tmp[2];
			my $suff_sub   = $tmp[3];
			#print $suff_pat . "\n";
			# apply rewrite rules
			if (($lcopy =~ /$stem_pat/) && ($su =~ /$suff_pat/)) {
				$lcopy =~ s/$stem_pat/"$stem_sub"/ee;
				$su =~ s/$suff_pat/"$suff_sub"/ee;
			}						
		}

		# if the suffix starts with "அ"
		if ( $su =~ /^அ/) {
			$lcopy =~ s/$VOWEL_SIGNS$//;
			$lcopy =~ s/்$//;
			$su =~ s/^அ//;
		} 
		 
		push @forms,  $lcopy . $su;
	}  
	return @forms;
}

1;

__END__

package Treex::Tool::DerivMorpho::Block::CS::RestructureClusters;
use Moose;
extends 'Treex::Tool::DerivMorpho::Block';
use Treex::Core::Log;


has file => (
    is            => 'ro',
    isa           => 'Str',
    documentation => q(file name to load),
);


sub process_dictionary {

    my ($self, $dict) = @_;

    my @files;
    if ($self->file) {
	@files = ($self->file);
    }
    else {
	glob $self->my_directory."manual.RestructureClusters/predelat*";
    }


    foreach my $filename (@files) {

        open my $R, '<:utf8', $filename or log_fatal($!);
        log_info("Loading cluster structures from $filename");


        my %targetpattern2sourcepattern;
        my %lemmas_in_cluster;
        my %patterns;
        my %pair_to_delete;
        while (<$R>) {


            my $to_delete = ($_ =~ s/^\s*\*\s*//);

            if ( /SPR.+: (.+)/ ) {
                my $pattern_description = $1;
                $pattern_description =~ s/\s+//g;
                my @pairs = split /,/,$pattern_description;
                foreach my $pair (@pairs) {
                    if ($pair =~ /(\S+)-->(\S+)/) {
                        my ($source,$target) = ($1,$2);
                        $targetpattern2sourcepattern{$target} = $source;
                        $patterns{$target}++;
                        $patterns{$source}++;
                        print "pattern pair $source --> $target\n";
                    }
                    else {
                        log_warn("Impossible to parse pair $pair");
                    }
                }
            }

            elsif (/GROUP/) {

            }

            elsif (/-->/) {
                my ($lemma1,$lemma2) = split /\t/;
                $lemmas_in_cluster{$lemma1} = 1;
                $lemmas_in_cluster{$lemma2} = 1;
                if ($to_delete) {
                    $pair_to_delete{$lemma1}{$lemma2}++;
                    $pair_to_delete{$lemma2}{$lemma1}++; # TODO: check the opposite direction
                    print "pair to delete: $lemma1 $lemma2\n";
                }
            }

            elsif (/^\s*$/) {

                # first, assing a lemma to each pattern "hraný" to "A-ý"
                my %pattern2lemma;
                foreach my $pattern (keys %patterns) {
                    my ($pos,$suffix) = split /-/,$pattern;
                    foreach my $lemma (keys %lemmas_in_cluster) {
                        if ($lemma =~ /$suffix$/) {
                            $pattern2lemma{$pattern} = $lemma;
                            print "patterntolemma $pattern: $lemma\n";
                        }
                    }
                }

                foreach my $target_pattern (keys %targetpattern2sourcepattern) {
                    my $source_pattern = $targetpattern2sourcepattern{$target_pattern};
                    my $source_lemma = $pattern2lemma{$source_pattern};
                    my $target_lemma = $pattern2lemma{$target_pattern};

                    print "trying to create pair $source_pattern -> $target_pattern :  $source_lemma -> $target_lemma\n";

                    if ($source_lemma and $target_lemma) {
                        my $source_pos = substr($source_pattern,0,1);
                        my $target_pos = substr($target_pattern,0,1);
                        my $source_lexeme = _create_if_nonexistent($source_lemma,$source_pos,$dict);
                        my $target_lexeme = _create_if_nonexistent($target_lemma,$target_pos,$dict);
                        if ($source_lexeme and $target_lexeme) {

                           if ( $source_lexeme eq ($target_lexeme->source_lexeme || '')) {
                               print " link $source_lemma->$target_lemma already exists\n";

                               if ($pair_to_delete{$source_lemma}{$target_lemma}) {
                                   print "deleting pair $source_lemma -> $target_lemma\n";
                                   if ($source_lexeme eq ( $target_lexeme->source_lexeme || '')) {
                                       print " the pair to delete was really present\n";
                                       $target_lexeme->set_source_lexeme(undef);
                                   }
                               }
                           }

                           else {
                               print "creating pair $source_lemma -> $target_lemma\n";
                               $dict->add_derivation({
                                   source_lexeme => $source_lexeme,
                                   derived_lexeme => $target_lexeme,
                                   deriv_type => $source_pos.'2'.$target_pos,
                                   derivation_creator => $self->signature.($self->file||""),
                               });
                            }
                        }
                    }
                }
                print "cluster finished\n\n";

                %lemmas_in_cluster = ();
                %pair_to_delete = ();

            }
        }
    }

    return $dict;
}


sub _create_if_nonexistent {
    my ($lemma,$pos,$dict) = @_;

    my @candidates = grep {$_->pos eq $pos} $dict->get_lexemes_by_lemma($lemma);
    if (not $candidates[0]) {
        log_info("No lexeme found for lemma=$lemma pos=$pos");
    }
    return $candidates[0]; # TODO: muze jich byt vic? a hlavne: kdyz se nenajde nic, mel by se vytvorit

}

1;

package Treex::Tool::LM::MorphoLM;
use Treex::Core::Common;
use utf8;
use English qw( -no_match_vars );

use Treex::Tool::LM::FormInfo;
use Class::Std;
use Readonly;
use Storable;
use PerlIO::gzip;
use Treex::Core::Common;

#use Smart::Comments;

Readonly my $DEFAULT_MODEL_FILENAME => 'data/models/language/cs/syn.pls.gz';

#Readonly my $DEFAULT_MODEL_FILENAME => 'data/models/language/cs/syn_mincount10.pls.gz';



# Each instance of this class has its model...
my %model_of : ATTR;

# ...but those models are shared across all instances if loaded from the same file name
my %loaded_models;

sub BUILD {
    my ( $self, $id, $arg_ref ) = @_;
    my $filename = $arg_ref->{'file'} // Treex::Core::Resource::require_file_from_share( $DEFAULT_MODEL_FILENAME, 'Treex::Tool::LM::MorphoLM' );
    my $model_ref = $loaded_models{$filename};
    if ( not defined $model_ref ) {
        log_info("Loading morpho model from '$filename' ...");
        log_fatal("Could not read morpho model: '$filename'.") if ( !-r $filename );
        open my $IN, '<:gzip', $filename or log_fatal($OS_ERROR);
        $model_ref = Storable::fd_retrieve($IN);
        log_fatal("Could not parse perl storable model: '$filename'.") if ( !defined $model_ref );
        close $IN or log_fatal($OS_ERROR);
        $loaded_models{$filename} = $model_ref;
    }
    $model_of{$id} = $model_ref;
    return;
}

sub forms_of_lemma {
    my ( $self, $lemma, $arg_ref ) = @_;
    log_fatal('No lemma given to forms_of_lemma()') if !defined $lemma;
    my $tag_regex = $arg_ref->{tag_regex}        || '.*';
    my $limit     = $arg_ref->{limit}            || 0;
    my $min_count = $arg_ref->{min_count}        || 0;
    my $lc_lemma  = $arg_ref->{lowercased_lemma} || 0;
    my $tc_forms = $arg_ref->{truecase_forms} // 1;
    #### Treex::Tool::LM::MorphoLM::forms_of_lemma(): $lemma
    #### $arg_ref

    $tag_regex = qr{$tag_regex};    #compile regex
    my $model_ref = $model_of{ ident $self};
    my $found     = 0;
    my @forms;
    my @all_forms = @{ $model_ref->{$lemma} || [] };
    if ($lc_lemma) {
        my @uc_forms = @{ $model_ref->{ ucfirst $lemma } || [] };
        if (@uc_forms) {
            @all_forms = sort { $b->[2] <=> $a->[2] } ( @all_forms, @uc_forms );
        }
    }

    foreach my $form_info_ref (@all_forms) {
        my ( $form, $tag, $count, $pdt_lemma ) = @{$form_info_ref};
        next if $tag !~ $tag_regex;
        next if $count < $min_count;

        if ( $tc_forms && $lemma =~ /^[\p{Uppercase}\P{Letter}]+$/ ) {
            $form = uc $form;
        }
        elsif ( $tc_forms && $lemma =~ /^\p{Uppercase}/ ) {
            $form = ucfirst $form;
        }
        if ( !defined $pdt_lemma ) { $pdt_lemma = $lemma; }

        my $form_info = Treex::Tool::LM::FormInfo->new( { form => $form, lemma => $pdt_lemma, tag => $tag, count => $count } );
        push @forms, $form_info;
        #### found: $form_info_ref
        last if $limit and ( ++$found >= $limit );
    }
    return @forms;
}

sub best_form_of_lemma {
    my ( $self, $lemma, $tag_regex, $arg_ref ) = @_;
    $arg_ref ||= {};
    $arg_ref->{tag_regex} = $tag_regex;
    $arg_ref->{limit}     = 1;
    my ($form_info) = $self->forms_of_lemma( $lemma, $arg_ref );
    return $form_info ? $form_info : undef;
}

1;

__END__

=pod

=head1 NAME

Treex::Tool::LM::MorphoLM - morphological language model


=head1 VERSION

0.01

=head1 SYNOPSIS

 use Treex::Tool::LM::MorphoLM;

 # load default model file
 my $morphoLM = Treex::Tool::LM::MorphoLM->new();


 my @forms = $morphoLM->forms_of_lemma('moci');
 foreach my $form_info (@forms){
     print join("\t", $form_info->get_form(), $form_info->get_tag(), $form_info->get_count()), "\n";
 }
 #Should print something like:
 # může   VB-S---3P-AA---I   426298
 # mohou  VB-P---3P-AA--1I   238013
 # mohl   VpYS---XR-AA---I   173695
 #etc.

 print 'Most frequent past participle of "moci" is: '
       , $morphoLM->best_form_of_lemma('moci', '^Vp'), "\n";
 #Should print: mohl

 # load user defined model file
 my $my_morphoLM = Treex::Tool::LM::MorphoLM->new({ file => '/path/to/my_frequencies.pls.gz' });

 # Now print only past participles of 'moci'
 @forms = $my_morphoLM->forms_of_lemma('moci', {tag_regex => '^Vp'});
 foreach my $form_info (@forms){
     print $form_info->to_string(), "\n";
 }

=head1 DESCRIPTION

This class returns counts of word forms and morphological tags for given lemma.
Numbers in the default model are extracted from the Czech National Corpus SYN
(i.e. data from SYN2006PUB, SYN2005 and SYN2000).

=over

=item * Capitalization

In the default model all forms are saved lowercased.
Therefore a capitalization is needed in case of proper names.
This feature is on by default, so 
if a lemma starts with a capital letter, forms will be capitalized.
To turn this feature off, use the C<< truecase_forms=>0 >> option.
On the other hand, if you want to get merged forms
of C<$lemma> and C<ucfirst $lemma>, use the C<lowercased_lemma> option.

=back

=head2 CONSTRUCTOR

=over

=item  C<my $morphoLM = Treex::Tool::LM::MorphoLM->new({file =E<gt> 'my_frequencies.pls.gz'});>

If called without any arguments, default model is used.
User models suitable for use with this class can be built
with the F<build_morphoLM.pl> script.

=back


=head2 METHODS

=over

=item  my @form_info_array = $morphoLM->forms_of_lemma($lemma, $additional_arguments_ref);

Second optional argument is a reference to a hash specifying additional aruments:

=over

=item * C<tag_regex>

Return only forms that match this regular expresion.
Be aware that in the default model tags have aspect on the 16th position.

=item * C<limit>

Return at most C<limit> forms.

=item * C<min_count>

Don't return forms with frequency count lower than C<min_count>.

=item * C<truecase_forms>

If a lemma starts with a capital letter, forms will be capitalized.

=item * C<lowercased_lemma>

Get merged forms for C<$lemma> and C<ucfirst $lemma>.

=back

=item  my $form = $morphoLM->best_form_of_lemma($lemma, $tag_regex);

Returns the most frequent word form of a given lemma
which matches a given regular expresion.

=back

=head1 TODO

=over

=item * Models sharing across instances

Models are now shared if loaded from the same file name.
So if two blocks use the default model (by calling the constructor
without arguments) the amount of memory needed is the same.
But file names are not normalized.

=back

=head1 AUTHOR

Martin Popel

=cut

# Copyright 2008 Martin Popel

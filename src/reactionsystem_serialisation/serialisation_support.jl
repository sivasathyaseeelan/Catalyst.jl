## String Handling ###

# Appends stuff to a string.
# E.g `@string_append! str_base str1 str2` becomes `str_base = str_base * str1 * str2`.
macro string_append!(string, inputs...)
    rhs = :($string * $(inputs[1]))
    for input in inputs[2:end]
        push!(rhs.args, input)
    end
    return esc(:($string = $rhs))
end

# Prepends stuff to a string. Can only take 1 or 2 inputs.
# E.g `@string_prepend! str1 str_base` becomes `str_base = str1 * str_base`.
macro string_prepend!(input, string)
    rhs = :($input * $string)
    return esc(:($string = $rhs))
end
macro string_prepend!(input1, input2, string)
    rhs = :($input1 * $input2 * $string)
    return esc(:($string = $rhs))
end


### Field Serialisation Support Functions ###

# Function which handles the addition of a single component to the file string.
function push_field(file_text::String, rn::ReactionSystem, annotate::Bool, comp_funcs::Tuple)
    has_component, get_comp_string, get_comp_annotation = comp_funcs
    has_component(rn) || (return (file_text, false))
    write_string = "\n" * get_comp_string(rn)
    annotate && (@string_prepend! "\n\n# " get_comp_annotation(rn) write_string)
    return (file_text * write_string, true)
end

# Generic function for creating an string for an unsupported argument.
function get_unsupported_comp_string(component::String)
    @warn "Writing ReactionSystem models with $(component) is currently not supported. This field is not written to the file."
    return ""
end

# Generic function for creating the annotation string for an unsupported argument.
function get_unsupported_comp_annotation(component::String)
    return "$(component): (OBS: Currently not supported, and hence empty)"
end


### String Conversion ###

# Converts a numeric expression (e.g. p*X + 2Y) to a string (e.g. "p*X + 2Y"). Also ensures that for
# any variables (e.g. X(t)) the call part is stripped, and only variable name (e.g. X) is written.
function expression_2_string(expr; strip_call_dict = make_strip_call_dict(Symbolics.get_variables(expr)))
    strip_called_expr = substitute(expr, strip_call_dict)
    return repr(strip_called_expr)
end

# Converts a vector of symbolics (e.g. the species or parameter vectors) to a string vector. Strips 
# any calls (e.g. X(t) becomes X). E.g. a species vector [X, Y, Z] is converted to "[X, Y, Z]".
function syms_2_strings(syms)
    strip_called_syms = [strip_call(Symbolics.unwrap(sym)) for sym in syms]
    return "$(convert(Vector{Any}, strip_called_syms))"[4:end]
end    

# Converts a vector of symbolics (e.g. the species or parameter vectors) to a string corresponding to 
# the code required to declare them (potential @parameters or @species commands must still be added).
# The `multiline_format` option formats it with a `begin ... end` block and declarations on separate lines.
function syms_2_declaration_string(syms; multiline_format = false)
    decs_string = (multiline_format ? " begin" : "")
    for sym in syms
        delimiter = (multiline_format ? "\n\t" : " ")
        @string_append! decs_string delimiter sym_2_declaration_string(sym; multiline_format)
    end
    multiline_format && (@string_append! decs_string "\nend")
    return decs_string
end

# Converts a symbolic (e.g. a species or parameter) to a string corresponding to how it would be declared
# in code. Takes default values and metadata into account. Example output "p=2.0 [bounds=(0.0, 1.0)]".
# The `multiline_format` option formats the string as if it is part of a `begin .. end` block.
function sym_2_declaration_string(sym; multiline_format = false)
    # Creates the basic symbol. The `"$(sym)"` ensures that we get e.g. "X(t)" and not "X".
    dec_string = "$(sym)"

    # If the symbol have a non-default type, appends the declaration of this.
    # Assumes that the type is on the form `SymbolicUtils.BasicSymbolic{X}`. Contain error checks
    # to ensure that this is the case.
    if !(sym isa SymbolicUtils.BasicSymbolic{Real})
        sym_type = String(Symbol(typeof(Symbolics.unwrap(k2))))
        if (sym_type[1:28] != "SymbolicUtils.BasicSymbolic{") || (sym_type[end] != '}')
            error("Encountered symbolic of unexpected type: $sym_type.")
        end
        @string_append! dec_string "::" sym_type[29:end-1]
    end

    # If there is a default value, adds this to the declaration.
    if ModelingToolkit.hasdefault(sym)
        def_val = x_2_string(ModelingToolkit.getdefault(sym))
        separator = (multiline_format ? " = " : "=")
        @string_append! dec_string separator "$(def_val)"
    end

    # Adds any metadata to the declaration.
    metadata_to_declare = get_metadata_to_declare(sym)
    if !isempty(metadata_to_declare)
        metadata_string = (multiline_format ? ", [" : " [")
        for metadata in metadata_to_declare
            @string_append! metadata_string metadata_2_string(sym, metadata) ", "
        end
        @string_append! dec_string metadata_string[1:end-2] "]"
    end

    # Returns the declaration entry for the symbol.
    return dec_string
end

# Converts a generic value to a String. Handles each type of value separately. Unsupported values might
# not necessarily generate valid code, and hence throw errors. Primarily used to write default values
# and metadata values (which hopefully almost exclusively) has simple, supported, types. Ideally,
# more supported types can be added here.
x_2_string(x::Num) = expression_2_string(x)
x_2_string(x::SymbolicUtils.BasicSymbolic{<:Real}) = expression_2_string(x)
x_2_string(x::Bool) = string(x)
x_2_string(x::String) = "\"$x\""
x_2_string(x::Char) = "\'$x\'"
x_2_string(x::Symbol) = ":$x"
x_2_string(x::Number) = string(x)
x_2_string(x::Pair) = "$(x_2_string(x[1])) => $(x_2_string(x[2]))"
x_2_string(x::Nothing) = "nothing"
function x_2_string(x::Vector)
    output = "["
    for val in x
        @string_append! output x_2_string(val) ", "
    end
    return output[1:end-2] * "]"
end 
function x_2_string(x::Tuple)
    output = "("
    for val in x
        @string_append! output x_2_string(val) ", "
    end
    return output[1:end-2] * ")"
end 
function x_2_string(x::Dict)
    output = "Dict(["
    for key in keys(x)
        @string_append! output x_2_string(key) " => " x_2_string(x[key]) ", "
    end
    return output[1:end-2] * "])"
end
function x_2_string(x::Union{Matrix, Symbolics.Arr{Any, 2}})
    output = "["
    for j = 1:size(x)[1]
        for i = 1:size(x)[2]
            @string_append! output x_2_string(x[j,i]) " "
        end
        output = output[1:end-1] * "; "
    end
    return output[1:end-2] *"]"
end 


x_2_string(x) = error("Tried to write an unsupported value ($(x)) of an unsupported type ($(typeof(x))) to a string.")


### Symbolics Metadata Handling ###

# For a Symbolic, retrieve all metadata that needs to be added to its declaration. Certain metadata 
# (such as default values and whether a variable is a species or not) are skipped (these are stored
# in the `SKIPPED_METADATA` constant).
# Because it is impossible to retrieve the keyword used to declare individual metadata from the
# metadata entry, these must be stored manually (in `RECOGNISED_METADATA`). If one of these are 
# encountered, a warning is thrown and it is skipped (we could also throw an error). I have asked
# Shashi, and he claims there is not alternative (general) solution.
function get_metadata_to_declare(sym)
    metadata_keys = collect(keys(sym.metadata))
    metadata_keys = filter(mdk -> !(mdk in SKIPPED_METADATA), metadata_keys)
    if any(!(mdk in keys(RECOGNISED_METADATA)) for mdk in metadata_keys)
        @warn "The following unrecognised metadata entries: $(setdiff(metadata_keys, keys(RECOGNISED_METADATA))) are not recognised for species/variable/parameter $sym. If you raise an issue at https://github.com/SciML/Catalyst.jl, we can add support for this metadata type."
        metadata_keys = filter(mdk -> in(mdk, keys(RECOGNISED_METADATA)), metadata_keys)
    end
    return metadata_keys
end

# Converts a given metadata into the string used to declare it. 
function metadata_2_string(sym, metadata)
    return RECOGNISED_METADATA[metadata] * " = " * x_2_string(sym.metadata[metadata])
end

# List of all recognised metadata (we should add as many as possible), and th keyword used to declare
# them in code.
const RECOGNISED_METADATA = Dict([
    Catalyst.ParameterConstantSpecies => "isconstantspecies"
    Catalyst.VariableBCSpecies => "isbcspecies"
    Catalyst.VariableSpecies => "isspecies"
    Catalyst.EdgeParameter => "edgeparameter"
    Catalyst.CompoundSpecies => "iscompound"
    Catalyst.CompoundComponents => "components"
    Catalyst.CompoundCoefficients => "coefficients"

    ModelingToolkit.VariableDescription => "description"
    ModelingToolkit.VariableBounds => "bounds"
    ModelingToolkit.VariableUnit => "unit"
    ModelingToolkit.VariableConnectType => "connect"
    ModelingToolkit.VariableNoiseType => "noise"
    ModelingToolkit.VariableInput => "input"
    ModelingToolkit.VariableOutput => "output"
    ModelingToolkit.VariableIrreducible => "irreducible"
    ModelingToolkit.VariableStatePriority => "state_priority"
    ModelingToolkit.VariableMisc => "misc"
    ModelingToolkit.TimeDomain => "timedomain"
])

# List of metadata that does not need to be explicitly declared to be added (or which is handled separately).
const SKIPPED_METADATA = [ModelingToolkit.MTKVariableTypeCtx, Symbolics.VariableSource, 
                          Symbolics.VariableDefaultValue, Catalyst.VariableSpecies]


### Generic Expression Handling ###

# Potentially strips the call for a symbolics. E.g. X(t) becomes X (but p remains p). This is used 
# when variables are written to files, as in code they are used without the call part.
function strip_call(sym)
    return istree(sym) ? Sym{Real}(Symbolics.getname(sym)) : sym
end

# For an vector of symbolics, creates a dictionary taking each symbolics to each call-stripped form.
function make_strip_call_dict(syms)
    return Dict([sym => strip_call(Symbolics.unwrap(sym)) for sym in syms])
end
function make_strip_call_dict(rn::ReactionSystem)
    return make_strip_call_dict(get_unknowns(rn))
end


### Handle Parameters/Species/Variables Declaration Dependencies ###

# Gets a vector with the symbolics a symbolic depends on (currently only considers defaults).
function get_dep_syms(sym)
    ModelingToolkit.hasdefault(sym) || return []
    return Symbolics.get_variables(ModelingToolkit.getdefault(sym))
end

# Checks if a symbolic depends on an symbolics in a vector being declared.
# Because Symbolics has to utilise `isequal`, the `isdisjoint` function cannot be used.
function depends_on(sym, syms)
    dep_syms = get_dep_syms(sym)
    for s1 in dep_syms
        for s2 in syms
            isequal(s1, s2) && return true
        end
    end
    return false
end

# For a set of remaining parameters/species/variables (remaining_syms), return this split into
# two sets:
# One with those that does not depend on any sym in `all_remaining_syms`.
# One with those that does depend on at least one sym in `all_remaining_syms`.
# The first set is returned. Next `remaining_syms` is updated to be the second set.
function dependency_split!(remaining_syms, all_remaining_syms)
    writable_syms = filter(sym -> !depends_on(sym, all_remaining_syms), remaining_syms)
    filter!(sym -> depends_on(sym, all_remaining_syms), remaining_syms)
    return writable_syms
end


### Other Functions ###


# Checks if a symbolic's declaration is "complicated". The declaration is considered complicated
# if it have metadata, default value, or type designation that must be declared.
function complicated_declaration(sym)
    isempty(get_metadata_to_declare(sym)) || (return true)
    ModelingToolkit.hasdefault(sym) && (return true)
    (sym isa SymbolicUtils.BasicSymbolic{Real}) || (return true)
    return false
end